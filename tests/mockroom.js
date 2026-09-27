(()=>{const me='p'+Math.random().toString(36).slice(2,8);
 const mk=(chName)=>{const ch=new BroadcastChannel(chName),peers=new Map();let mine={};const subs=new Set();
  const snap=()=>[...peers.values()].concat([{peer:me,sameTab:true,isMe:true,by:null,kind:'viewer',guest:false,presence:Object.freeze({...mine}),updatedAt:Date.now()}]);
  const notify=()=>{const ps=snap();subs.forEach(f=>f({peers:ps,joined:[],updated:[],left:[]}));};
  ch.onmessage=e=>{const m=e.data;if(m.t==='p'){peers.set(m.peer,{peer:m.peer,sameTab:false,isMe:false,by:null,kind:'viewer',guest:false,presence:Object.freeze(m.p),updatedAt:Date.now()});notify();}
    else if(m.t==='hi')ch.postMessage({t:'p',peer:me,p:mine});else if(m.t==='bye'){peers.delete(m.peer);notify();}};
  ch.postMessage({t:'hi'});
  return {name:chName,presence:async patch=>{for(const k in patch){if(patch[k]===null)delete mine[k];else mine[k]=patch[k];}ch.postMessage({t:'p',peer:me,p:JSON.parse(JSON.stringify(mine))});notify();},
   peers:()=>snap(),onPeers:f=>{subs.add(f);setTimeout(()=>f({peers:snap(),joined:snap()}),0);return()=>subs.delete(f);},connected:()=>true,onConnection:()=>()=>{},leave:async()=>{ch.postMessage({t:'bye',peer:me});ch.close();},emit:async()=>{},on:()=>()=>{}};};
 const lobby=mk('lobby');lobby.join=async n=>mk('room-'+n);window.claude={use:async n=>n==='room'?lobby:null};})();
