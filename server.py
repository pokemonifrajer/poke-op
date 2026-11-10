import os, re, json, hmac, sqlite3, uuid, subprocess, threading, urllib.request, time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse
from flask import Flask, request, jsonify, session, send_file, send_from_directory
from werkzeug.utils import secure_filename

BASE=Path("/tmp/nicheflow-data")
MEDIA=BASE/"media"; CLIPS=BASE/"clips"; MODELS=BASE/"models"
for p in (MEDIA,CLIPS,MODELS): p.mkdir(parents=True,exist_ok=True)
app=Flask(__name__, static_folder="static")
app.secret_key=os.environ["APP_SECRET"]
app.config.update(MAX_CONTENT_LENGTH=180*1024*1024,SESSION_COOKIE_SECURE=True,SESSION_COOKIE_HTTPONLY=True,SESSION_COOKIE_SAMESITE="Lax")
PASS=os.environ["APP_PASSWORD"]
POOL=ThreadPoolExecutor(max_workers=1)
LOCK=threading.Lock()
JOBS={}
LOGIN={}
WHISPER=None
KOKORO=None
OWNED_NICHES=["Gaming","Streamers","Podcasts","Technology","Sports","Business","Science","Stories"]
VOICES=["af_heart","af_bella","af_nova","am_michael","am_adam","bm_george","bf_emma"]

def connect():
 c=sqlite3.connect(BASE/"studio.sqlite",timeout=20)
 c.row_factory=sqlite3.Row
 return c

with connect() as c:
 c.execute("CREATE TABLE IF NOT EXISTS sources(id TEXT PRIMARY KEY,title TEXT,niche TEXT,path TEXT,duration REAL,analysis TEXT,created INTEGER)")
 c.execute("CREATE TABLE IF NOT EXISTS clips(id TEXT PRIMARY KEY,source TEXT,title TEXT,path TEXT,status TEXT,created INTEGER)")
 c.execute("CREATE TABLE IF NOT EXISTS settings(id INTEGER PRIMARY KEY,niches TEXT,daily INTEGER,voice TEXT)")
 c.execute("INSERT OR IGNORE INTO settings(id,niches,daily,voice) VALUES(1,'[\"Gaming\"]',3,'af_heart')")

def settings():
 with connect() as c:
  r=c.execute("SELECT * FROM settings WHERE id=1").fetchone()
 return dict(niches=json.loads(r["niches"]),daily=r["daily"],voice=r["voice"])

def rows(table):
 with connect() as c:
  return [dict(r) for r in c.execute("SELECT * FROM "+table+" ORDER BY created DESC LIMIT 80").fetchall()]

def obj(table,id):
 with connect() as c:
  r=c.execute("SELECT * FROM "+table+" WHERE id=?",(id,)).fetchone()
 return dict(r) if r else None

def run(args,timeout=360):
 p=subprocess.run(args,capture_output=True,text=True,timeout=timeout)
 if p.returncode: raise RuntimeError((p.stderr or p.stdout or "Processing failed")[-450:])
 return p.stdout

def probe(path):
 j=json.loads(run(["ffprobe","-v","error","-show_entries","format=duration:stream=codec_type,width,height","-of","json",str(path)],20))
 v=next((s for s in j.get("streams",[]) if s.get("codec_type")=="video"),None)
 if not v: raise ValueError("No video track found")
 return float(j["format"]["duration"])

def submit(kind,func,*args):
 ident=uuid.uuid4().hex
 with LOCK: JOBS[ident]={"id":ident,"kind":kind,"status":"queued","message":"Waiting"}
 def task():
  with LOCK: JOBS[ident].update(status="working",message="Processing")
  try:
   result=func(*args)
   with LOCK: JOBS[ident].update(status="done",message="Ready",result=result)
  except Exception as e:
   with LOCK: JOBS[ident].update(status="failed",message=str(e)[-240:])
 POOL.submit(task)
 return ident

def whisper():
 global WHISPER
 if WHISPER is None:
  from faster_whisper import WhisperModel
  WHISPER=WhisperModel("tiny.en",device="cpu",compute_type="int8",cpu_threads=2,num_workers=1)
 return WHISPER

def speech(path,words=False):
 segments,_=whisper().transcribe(str(path),language="en",beam_size=1,vad_filter=True,word_timestamps=words)
 result=[]
 for s in segments:
  item={"start":float(s.start),"end":float(s.end),"text":s.text.strip()}
  if words and s.words: item["words"]=[{"start":float(w.start),"end":float(w.end),"word":w.word.strip()} for w in s.words]
  result.append(item)
 return result

def find_moments(srcid):
 src=obj("sources",srcid)
 if not src: raise ValueError("Source not found")
 duration=src["duration"]
 try: segments=speech(src["path"])
 except Exception: segments=[]
 windows=[]
 for step in (18,30,42):
  for start in range(0,max(1,int(duration)-11),max(9,step//2)):
   end=min(duration,start+step)
   if end-start<12: continue
   active=[s for s in segments if s["end"]>start and s["start"]<end]
   transcript=" ".join(s["text"] for s in active)
   hooks=sum(transcript.lower().count(w) for w in ["why","how","wait","but","never","secret","actually","crazy","best","what","really","imagine"])
   coverage=sum(max(0,min(end,s["end"])-max(start,s["start"])) for s in active)/max(1,end-start)
   score=round(min(95,30+min(38,hooks*6)+min(22,coverage*25)+(10 if "?" in transcript[:140] else 0)))
   windows.append(dict(start=round(start,2),duration=round(end-start,2),score=score,excerpt=transcript[:180] or "Transcript unavailable. Review manually.",reason="Speech density and hook words" if transcript else "Even interval fallback"))
 windows.sort(key=lambda x:x["score"],reverse=True)
 best=[]
 for c in windows:
  if all(abs(c["start"]-b["start"])>10 for b in best):best.append(c)
  if len(best)>=15:break
 with connect() as db:db.execute("UPDATE sources SET analysis=? WHERE id=?",(json.dumps(best),srcid))
 return {"moments":best,"method":"Speech/word heuristic; not a view prediction"}

def kokoro():
 global KOKORO
 if KOKORO is not None:return KOKORO
 from kokoro_onnx import Kokoro
 base="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/"
 for filename,minimum in [("kokoro-v1.0.int8.onnx",60_000_000),("voices-v1.0.bin",15_000_000)]:
  dest=MODELS/filename
  if not dest.exists() or dest.stat().st_size<minimum:
   temp=MODELS/(filename+".part")
   urllib.request.urlretrieve(base+filename,temp)
   if temp.stat().st_size<minimum: raise ValueError("Incomplete Kokoro download")
   temp.replace(dest)
 KOKORO=Kokoro(str(MODELS/"kokoro-v1.0.int8.onnx"),str(MODELS/"voices-v1.0.bin"))
 return KOKORO

def make_voice(text,voice,out):
 if voice not in VOICES:raise ValueError("Unknown voice")
 if not text.strip() or len(text)>600:raise ValueError("Voice text must be 1-600 characters")
 import soundfile as sf
 audio,rate=kokoro().create(text,voice=voice,speed=1.04,lang="en-gb" if voice.startswith(("bm_","bf_")) else "en-us")
 sf.write(str(out),audio,rate)
 return str(out)

def ass_captions(words,path):
 lines=['[Script Info]','ScriptType: v4.00+','PlayResX: 720','PlayResY: 1280','[V4+ Styles]','Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding','Style: Default,Arial,66,&H00FFFFFF,&H0000CFFF,&H00102044,&H60000000,1,0,0,0,100,100,0,0,1,4,2,2,35,35,250,1','[Events]','Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text']
 def ts(x):
  h=int(x//3600);m=int(x//60)%60; s=x%60
  return f"{h}:{m:02}:{s:05.2f}"
 for w in words:
  if w["end"]<=w["start"]: continue
  t=re.sub(r"[{}\\]","",w["word"]).replace(","," ")
  lines.append(f"Dialogue: 0,{ts(w['start'])},{ts(w['end'])},Default,,0,0,0,,{{\\fad(70,90)}}{t.upper()}")
 path.write_text("\n".join(lines))
 return len(lines)>8

def export_clip(srcid,start,duration,title,voice_text,with_captions):
 src=obj("sources",srcid)
 if not src:raise ValueError("Source missing")
 start=float(start);duration=float(duration)
 if start<0 or duration<12 or duration>60 or start+duration>src["duration"]+.15:raise ValueError("Invalid clip boundaries")
 clipid=uuid.uuid4().hex
 dest=CLIPS/(clipid+".mp4")
 excerpt=MEDIA/(clipid+"-excerpt.mp4")
 voice=MEDIA/(clipid+"-voice.wav")
 ass=MEDIA/(clipid+".ass")
 try:
  run(["ffmpeg","-hide_banner","-loglevel","error","-y","-ss",str(start),"-i",src["path"],"-t",str(duration),"-c:v","libx264","-preset","ultrafast","-crf","29","-c:a","aac",str(excerpt)],350)
  voice_active=bool(voice_text.strip())
  if voice_active:make_voice(voice_text,settings()["voice"],voice)
  caption_words=[]
  if with_captions:
   if voice_active:
    vdur=float(json.loads(run(["ffprobe","-v","quiet","-show_entries","format=duration","-of","json",str(voice)]) )["format"]["duration"])
    toks=voice_text.split();tick=min(duration,vdur)/max(1,len(toks))
    caption_words=[{"start":i*tick,"end":(i+1)*tick,"word":t} for i,t in enumerate(toks)]
   else:
    try:
     for seg in speech(excerpt,True):
      caption_words.extend(seg.get("words",[]))
    except Exception:caption_words=[]
  has_sub=ass_captions(caption_words,ass) if caption_words else False
  fc=("[0:v]fps=25,split=2[b][f];"
      "[b]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,boxblur=12:1,eq=brightness=-0.13[bg];"
      "[f]scale=720:1280:force_original_aspect_ratio=decrease[fg];"
      "[bg][fg]overlay=x=(W-w)/2+5*sin(t/3):y=(H-h)/2,format=yuv420p")
  if has_sub:fc+=f",subtitles='{ass}'"
  fc+="[v]"
  cmd=["ffmpeg","-hide_banner","-loglevel","error","-y","-i",str(excerpt)]
  if voice_active:
   cmd+=["-i",str(voice)]
   fc+=";[0:a]volume=0.20[bed];[1:a]volume=1.05[narr];[bed][narr]amix=inputs=2:duration=first[a]"
   amap=["-map","[a]"]
  else:amap=["-map","0:a?"]
  cmd+=["-filter_complex",fc,"-map","[v]"]+amap+["-t",str(duration),"-c:v","libx264","-preset","ultrafast","-crf","27","-c:a","aac","-movflags","+faststart",str(dest)]
  run(cmd,360)
  if dest.stat().st_size<3000:raise RuntimeError("Output video too small")
  with connect() as db:db.execute("INSERT INTO clips VALUES(?,?,?,?,?,?)",(clipid,srcid,title[:110],str(dest),"ready",int(time.time())))
  return {"clip_id":clipid,"download":"/api/file/"+clipid}
 finally:
  for p in (excerpt,voice,ass):
   try:p.unlink()
   except FileNotFoundError:pass

def import_url(url,niche):
 domain=urlparse(url).hostname or ""
 if domain not in ("youtube.com","www.youtube.com","youtu.be","www.youtu.be","vimeo.com","www.vimeo.com","streamable.com"):
  raise ValueError("Only YouTube, Vimeo and Streamable URLs are supported")
 if niche not in settings()["niches"]: raise ValueError("Choose an active niche")
 ident=uuid.uuid4().hex;target=MEDIA/(ident+".mp4")
 run(["yt-dlp","--no-playlist","--max-filesize","170M","--merge-output-format","mp4","-f","bv*[height<=720]+ba/best[height<=720]","-o",str(target),url],300)
 if not target.is_file():raise ValueError("Video could not be imported")
 duration=probe(target)
 with connect() as db:db.execute("INSERT INTO sources VALUES(?,?,?,?,?,?,?)",(ident,url[:100],niche,str(target),duration,None,int(time.time())))
 return {"source_id":ident,"duration":duration}

@app.after_request
def headers(resp):
 resp.headers["X-Content-Type-Options"]="nosniff"
 resp.headers["Referrer-Policy"]="same-origin"
 resp.headers["X-Frame-Options"]="DENY"
 resp.headers["Cache-Control"]="no-store"
 return resp

@app.before_request
def guard():
 if request.path=="/healthz" or request.path=="/" or request.path.startswith("/static/") or request.path=="/api/login":return
 if not session.get("ok"):return jsonify(error="Sign in required"),401

@app.route("/")
def home():return send_from_directory("static","index.html")
@app.route("/healthz")
def health():return jsonify(ok=True,version="independent-1")
@app.route("/api/login",methods=["POST"])
def login():
 ip=request.headers.get("X-Forwarded-For",request.remote_addr or "?").split(",")[0]
 times=[t for t in LOGIN.get(ip,[]) if time.time()-t<900]
 if len(times)>=8:return jsonify(error="Too many attempts. Try again later."),429
 data=request.get_json(silent=True) or {}
 if not hmac.compare_digest(str(data.get("password","")),PASS):
  times.append(time.time());LOGIN[ip]=times;return jsonify(error="Incorrect password"),401
 LOGIN.pop(ip,None);session.clear();session["ok"]=True
 return jsonify(ok=True)
@app.route("/api/logout",methods=["POST"])
def logout():session.clear();return jsonify(ok=True)
@app.route("/api/state")
def state():
 s=rows("sources")
 for row in s:row.pop("path",None);row["moments"]=json.loads(row.pop("analysis") or "[]")
 clips=rows("clips")
 for row in clips:row.pop("path",None)
 return jsonify(settings=settings(),sources=s,clips=clips,jobs=list(JOBS.values())[-30:],voices=VOICES,niches=OWNED_NICHES,storage_notice="Free hosting may erase uploads when sleeping or redeploying.",youtube_connected=False)
@app.route("/api/settings",methods=["POST"])
def save_settings():
 j=request.get_json(silent=True) or {}
 ns=j.get("niches",[]);daily=j.get("daily",0);voice=j.get("voice","")
 if not isinstance(ns,list) or not 1<=len(ns)<=3 or len(ns)!=len(set(ns)) or any(n not in OWNED_NICHES for n in ns) or type(daily)!=int or not 3<=daily<=10 or voice not in VOICES:return jsonify(error="Choose 1-3 niches, 3-10 clips and a voice."),400
 with connect() as db:db.execute("UPDATE settings SET niches=?,daily=?,voice=? WHERE id=1",(json.dumps(ns),daily,voice))
 return jsonify(ok=True)
@app.route("/api/upload",methods=["POST"])
def upload():
 niche=request.form.get("niche","")
 if niche not in settings()["niches"]:return jsonify(error="Choose an active niche"),400
 file=request.files.get("video")
 if not file or not file.filename:return jsonify(error="Choose a video file"),400
 if Path(secure_filename(file.filename)).suffix.lower() not in (".mp4",".mov",".mkv",".webm"):
  return jsonify(error="MP4, MOV, MKV or WEBM only"),400
 ident=uuid.uuid4().hex;path=MEDIA/(ident+Path(file.filename).suffix.lower())
 file.save(path)
 try:duration=probe(path)
 except Exception as e:path.unlink(missing_ok=True);return jsonify(error=str(e)),400
 with connect() as db:db.execute("INSERT INTO sources VALUES(?,?,?,?,?,?,?)",(ident,secure_filename(file.filename)[:100],niche,str(path),duration,None,int(time.time())))
 return jsonify(ok=True,source_id=ident,duration=duration)
@app.route("/api/import",methods=["POST"])
def start_import():
 j=request.get_json(silent=True) or {}
 if not j.get("licensed"):return jsonify(error="Confirm you own or have permission for the video"),400
 return jsonify(job_id=submit("import",import_url,str(j.get("url","")),str(j.get("niche",""))))
@app.route("/api/analyze",methods=["POST"])
def analyze():
 j=request.get_json(silent=True) or {}
 sid=str(j.get("source_id",""))
 if not obj("sources",sid):return jsonify(error="Source missing"),404
 return jsonify(job_id=submit("discover",find_moments,sid))
@app.route("/api/render",methods=["POST"])
def render():
 j=request.get_json(silent=True) or {}
 sid=str(j.get("source_id",""));src=obj("sources",sid)
 if not src:return jsonify(error="Source missing"),404
 try: st=float(j.get("start",0));dr=float(j.get("duration",30))
 except ValueError:return jsonify(error="Invalid timing"),400
 if not 0<=st<src["duration"] or not 12<=dr<=60 or st+dr>src["duration"]+.2:return jsonify(error="Invalid clip timing"),400
 voice=str(j.get("voice_text",""))[:600]
 return jsonify(job_id=submit("render",export_clip,sid,st,dr,str(j.get("title","Clip"))[:100],voice,bool(j.get("captions",True))))
@app.route("/api/batch",methods=["POST"])
def batch():
 j=request.get_json(silent=True) or {};sid=str(j.get("source_id",""));src=obj("sources",sid)
 if not src:return jsonify(error="Source missing"),404
 n=settings()["daily"];length=src["duration"]
 ids=[]
 for i in range(min(n,max(1,int(length//15)))):
  st=max(0,min(length-15,round(i*length/max(n,1),1)))
  ids.append(submit("render",export_clip,sid,st,min(30,length-st),f"Clip {i+1}", "",True))
 return jsonify(job_ids=ids,note="Batch jobs are queued, not automatically published")
@app.route("/api/voice",methods=["POST"])
def preview():
 j=request.get_json(silent=True) or {}
 text=str(j.get("text",""))[:600];voice=str(j.get("voice",settings()["voice"]))
 path=MEDIA/(uuid.uuid4().hex+".wav")
 return jsonify(job_id=submit("voice",lambda:{"file":"/api/voice-file/"+path.stem} if make_voice(text,voice,path) else {}))
@app.route("/api/voice-file/<fid>")
def audio(fid):
 if not re.fullmatch(r"[a-f0-9]{32}",fid):return jsonify(error="Missing file"),404
 path=MEDIA/(fid+".wav")
 if not path.is_file():return jsonify(error="Missing file"),404
 return send_file(path,mimetype="audio/wav")
@app.route("/api/file/<cid>")
def file(cid):
 r=obj("clips",cid)
 if not r or not Path(r["path"]).is_file():return jsonify(error="Clip not found"),404
 return send_file(r["path"],as_attachment=True,download_name="nicheflow-"+cid[:8]+".mp4",mimetype="video/mp4")

if __name__=="__main__":app.run(port=int(os.environ.get("PORT","10000")),host="0.0.0.0")
