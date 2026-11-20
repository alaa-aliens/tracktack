/* b25: open from the phone's copy right away, then fetch the new files in the background.
   version.txt always goes to the network so the app can tell when an update is ready. */
const C='tamm-v15';
self.addEventListener('install',e=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==C).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=='GET'||u.origin!==location.origin)return;
  if(u.pathname.endsWith('/version.txt')||u.pathname.endsWith('/sw.js')||u.searchParams.has('fresh'))return;
  const key=e.request.mode==='navigate'?new Request(u.origin+u.pathname):e.request;
  const net=fetch(e.request,{cache:'no-cache'}).then(r=>{if(r&&r.ok){const c=r.clone();caches.open(C).then(ca=>ca.put(key,c));}return r;});
  e.respondWith(caches.match(key).then(hit=>{if(hit){e.waitUntil(net.catch(()=>{}));return hit;}return net.catch(()=>caches.match(key));}));
});
