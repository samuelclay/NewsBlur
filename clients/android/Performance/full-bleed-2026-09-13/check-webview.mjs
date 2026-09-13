// check-webview.mjs exercises the shipped reader assets in an isolated iframe in an attached debug WebView.
// Forward its devtools socket to port 9223 first. No account data or story state is changed.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const assets = new URL('../../NewsBlur/app/src/main/assets/', import.meta.url);
const css = fs.readFileSync(new URL('reading.css', assets), 'utf8');
const js = fs.readFileSync(new URL('storyDetailView.js', assets), 'utf8');
const targets = await (await fetch('http://127.0.0.1:9223/json/list')).json();
const target = targets.find(t => JSON.parse(t.description).screenX === 0);
assert.ok(target, 'Open a story in the attached debug app');
const ws = new WebSocket(target.webSocketDebuggerUrl);
const timeout = setTimeout(() => { ws.close(); throw new Error('WebView test timed out'); }, 30000);
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
const run = async ({css, js}) => {
  const frame = document.createElement('iframe');
  frame.style.cssText = 'position:fixed;top:0;left:0;width:393px!important;max-width:none!important;height:600px;opacity:0;pointer-events:none;border:0;z-index:-1';
  document.body.appendChild(frame);
  const d = frame.contentDocument;
  const svg = (w,h) => 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="orange"/></svg>`);
  d.open();d.write(`<style>${css}</style><div class="NB-story"><p id="text">Text keeps its reading margin.</p><img id="wide" src="${svg(1200,600)}"><figure><a href="#"><img id="linked" src="${svg(1000,500)}"></a><figcaption>Caption</figcaption></figure><div style="padding:0 20px"><figure><img id="nested" class="publisher-photo" src="${svg(1200,600)}"><figcaption id="caption">Nested caption</figcaption></figure></div><img id="portrait" src="${svg(1200,1800)}"><img id="banner" src="${svg(1200,20)}"><blockquote><img id="quote" src="${svg(1200,600)}"></blockquote><img id="declared-small" width="80" src="${svg(1200,600)}"><img id="styled-small" style="width:80px" src="${svg(1200,600)}"><div style="overflow:hidden;padding:10px"><img id="clipped" src="${svg(1200,600)}"></div><img id="floated" style="float:right" src="${svg(1200,600)}"><img id="small" src="${svg(80,60)}"><img id="icon" class="NB-briefing-inline-favicon" src="${svg(1000,1000)}"><p>Inline <img id="inline" src="${svg(1000,500)}"> text</p><ul><li><img id="list" src="${svg(1000,500)}"></li></ul><table><tr><td><img id="table" src="${svg(1000,500)}"></td></tr></table><img id="delayed"><img id="responsive" src="${svg(600,300)}"></div>`);d.close();
  frame.contentWindow.eval(js);
  const wait = () => new Promise(r => setTimeout(r, 100));
  const rows=[];
  try {
    await Promise.all(Array.from(d.images).filter(i=>i.src).map(i=>i.decode()));
    frame.contentWindow.loadImages();await wait();
    const rect=id=>{const i=d.getElementById(id),r=i.getBoundingClientRect();return {left:r.left,right:r.right,width:r.width,height:r.height,bleed:i.classList.contains('NB-large-image')};};
    const near=(a,b)=>Math.abs(a-b)<1;
    const check=(name,ok,actual)=>rows.push({name,ok,actual});
    const full=(id,w)=>{const r=rect(id);check(`${id} fills ${w}px pane`,near(r.left,0)&&near(r.right,w),r);};
    full('wide',393);full('linked',393);full('nested',393);full('portrait',393);
    check('publisher classes survive',d.getElementById('nested').classList.contains('publisher-photo'),d.getElementById('nested').className);
    check('nested caption keeps its inset',rect('caption').left>=31,rect('caption'));
    check('portrait aspect ratio stays natural',near(rect('portrait').height/rect('portrait').width,1.5),rect('portrait'));
    const original=rect('wide');frame.contentWindow.loadImages();frame.contentWindow.loadImages();await wait();check('repeated initialization is stable',near(rect('wide').left,original.left)&&near(rect('wide').width,original.width),rect('wide'));
    check('text stays inset',rect('text').left>=11,rect('text'));
    for(const id of ['small','icon','inline','list','table','quote','banner','declared-small','styled-small','clipped','floated'])check(`${id} stays contained`,!rect(id).bleed,rect(id));
    check('small image is not enlarged',rect('small').width<=80,rect('small'));
    d.getElementById('delayed').src=svg(1200,600);await d.getElementById('delayed').decode();await wait();full('delayed',393);
    full('responsive',393);
    frame.style.setProperty('width','700px','important');frame.getBoundingClientRect();await wait();full('wide',700);
    check('image too small for wider pane loses full bleed',!rect('responsive').bleed,rect('responsive'));
    check('no horizontal document overflow',d.documentElement.scrollWidth<=701,d.documentElement.scrollWidth);
    frame.style.setProperty('width','393px','important');frame.getBoundingClientRect();await wait();full('responsive',393);
    return rows;
  } finally {frame.remove();}
};
const result = new Promise(resolve => ws.onmessage = event => { const message=JSON.parse(event.data);if(message.id===1)resolve(message); });
ws.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression:`(${run.toString()})(${JSON.stringify({css,js})})`,awaitPromise:true,returnByValue:true}}));
const response=await result;clearTimeout(timeout);ws.close();
assert.ok(!response.result?.exceptionDetails,JSON.stringify(response));
const rows=response.result.result.value;
for(const row of rows)console.log(`${row.ok?'PASS':'FAIL'} ${row.name}: ${JSON.stringify(row.actual)}`);
assert.equal(rows.filter(r=>!r.ok).length,0,'Reader image layout checks');
