NEWSBLUR.generate_bookmarklet = function() {
    var $bookmarklet = $.make('a', { 
        className: 'NB-goodies-bookmarklet-button',
        href: "javascript:function newsblur_bookmarklet() { var d=document,z=d.createElement('scr'+'ipt'),b=d.body,l=d.location; try{ if(!b) { throw(0); } z.setAttribute('src',l.protocol+'/'+'/'+'nb.local.host:8000'+'/api/add_site/'+NEWSBLUR.Globals.secret_token+'?url='+encodeURIComponent(l.href)+'&time='+(new Date().getTime())); b.appendChild(z); } catch(e) {alert('Please wait until the page has loaded.');}}newsblur_bookmarklet();void(0)"
    }, 'Add to NewsBlur');
    
    return $bookmarklet;
};