(() => {
 const story=document.querySelector('.NB-story');
 window.__imageQAOriginal ??= story.innerHTML;
 const sample=(width,height,label)=>{
  const c=document.createElement('canvas');c.width=width;c.height=height;
  const g=c.getContext('2d');g.fillStyle='#245878';g.fillRect(0,0,width,height);
  g.fillStyle='#65b3bf';g.fillRect(width/2,0,width/2,height/2);
  g.fillStyle='#dfad6e';g.fillRect(0,height/2,width/2,height/2);
  g.strokeStyle='#ffffff';g.lineWidth=3;
  for(let x=0;x<width;x+=100){g.beginPath();g.moveTo(x,0);g.lineTo(x,height);g.stroke();}
  for(let y=0;y<height;y+=100){g.beginPath();g.moveTo(0,y);g.lineTo(width,y);g.stroke();}
  g.fillStyle='white';g.font='bold 48px sans-serif';g.fillText(label,30,70);
  return c.toDataURL('image/png');
 };
 window.__imageQASources={
  landscape:sample(1200,800,'Landscape'), panorama:sample(1600,220,'Panorama'),
  portrait:sample(250,1400,'Tall'), small:sample(40,30,'')
 };
 window.__showImageQA=(kind)=>{
   const src=kind==='cached'?'https://appassets.androidplatform.net/images/viewer-qa.jpg':window.__imageQASources[kind];
   story.innerHTML='<p>Image viewer device check</p><a href="https://example.com/image-link"><img id="image-qa" alt="'+kind+' image" src="'+src+'"></a><p>Article remains in place below the image.</p>';
   return kind;
 };
 return window.__showImageQA('cached');
})()
