window.__zfight=(root,opts)=>{opts=opts||{};const faces=[],m4=new THREE.Matrix4(),im=new THREE.Matrix4(),v=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();
 const ax=[new THREE.Vector3(),new THREE.Vector3(),new THREE.Vector3()];let nb=0;const solids=[];
 const addBox=(M,w,h,d,mat,tag)=>{M.decompose(v,q,s);if(Math.abs(s.x*s.y*s.z)<1e-9)return;const he=[w*s.x/2,h*s.y/2,d*s.z/2];ax[0].set(1,0,0).applyQuaternion(q);ax[1].set(0,1,0).applyQuaternion(q);ax[2].set(0,0,1).applyQuaternion(q);nb++;
   if(!(mat&&mat.transparent))solids.push({c:v.clone(),a:[ax[0].clone(),ax[1].clone(),ax[2].clone()],he:he.slice(),tag});
   for(let a=0;a<3;a++)for(const sg of [-1,1]){const n=ax[a].clone().multiplyScalar(sg),c=v.clone().addScaledVector(ax[a],sg*he[a]),b=(a+1)%3,e=(a+2)%3;
     faces.push({n,c,u:ax[b].clone(),vv:ax[e].clone(),hu:he[b],hv:he[e],mat,tag});}};
 const addPlane=(M,w,h,mat,tag)=>{M.decompose(v,q,s);const n=new THREE.Vector3(0,0,1).applyQuaternion(q),u=new THREE.Vector3(1,0,0).applyQuaternion(q),vv=new THREE.Vector3(0,1,0).applyQuaternion(q);
   faces.push({n,c:v.clone(),u,vv,hu:w*s.x/2,hv:h*s.y/2,mat,tag,plane:true});if(mat&&mat.side===THREE.DoubleSide)faces.push({n:n.clone().negate(),c:v.clone(),u,vv,hu:w*s.x/2,hv:h*s.y/2,mat,tag,plane:true});};
 root.updateMatrixWorld(true);
 root.traverse(o=>{if(!o.isMesh||!o.visible)return;let vis=true;o.traverseAncestors(a=>{if(!a.visible)vis=false;});if(!vis)return;const p=o.geometry.parameters||{},t=o.geometry.type;
   const tag=(o.name||t)+'#'+o.id;const mats=Array.isArray(o.material)?o.material[4]:o.material;
   if(o.isInstancedMesh){for(let k=0;k<o.count;k++){o.getMatrixAt(k,im);m4.multiplyMatrices(o.matrixWorld,im);if(t==='BoxGeometry')addBox(m4,p.width,p.height,p.depth,mats,tag+'['+k+']');else if(t==='PlaneGeometry')addPlane(m4,p.width,p.height,mats,tag+'['+k+']');}}
   else if(t==='BoxGeometry')addBox(o.matrixWorld,p.width,p.height,p.depth,mats,tag);else if(t==='PlaneGeometry')addPlane(o.matrixWorld,p.width,p.height,mats,tag);});
 const key=f=>{const n=f.n;return [Math.round(n.x*50),Math.round(n.y*50),Math.round(n.z*50),Math.round(n.dot(f.c)/0.02)].join(',');};
 const H=new Map();for(const f of faces){const k=key(f);if(!H.has(k))H.set(k,[]);H.get(k).push(f);}
 const hits=[];const tmp=new THREE.Vector3();
 for(const f of faces){const n=f.n,base=[Math.round(n.x*50),Math.round(n.y*50),Math.round(n.z*50)],dq=Math.round(n.dot(f.c)/0.02);
   for(const dd of [0,1]){const L=H.get(base.concat([dq+dd]).join(','));if(!L)continue;for(const g of L){if(g===f||(dd===0&&g.tag<=f.tag))continue;if(g.tag.split('[')[0]===f.tag.split('[')[0]&&g.mat===f.mat&&!opts.same)continue;
     if(n.dot(g.n)<0.9995)continue;if(n.y<-0.9&&f.c.y-(opts.y0||0)<0.35)continue;if(Math.abs(n.dot(g.c)-n.dot(f.c))>0.004)continue;
     // 2D overlap in plane using SAT on the 4 edge axes
     tmp.subVectors(g.c,f.c);let sep=false,area=1;for(const [A,la] of [[f.u,0],[f.vv,1],[g.u,2],[g.vv,3]]){const ra=f.hu*Math.abs(A.dot(f.u))+f.hv*Math.abs(A.dot(f.vv)),rb=g.hu*Math.abs(A.dot(g.u))+g.hv*Math.abs(A.dot(g.vv)),d=Math.abs(tmp.dot(A)),ov=ra+rb-d;if(ov<=0.005){sep=true;break;}if(la<2)area*=Math.min(ov,2*Math.min(ra,rb));}
     if(sep||area<0.004)continue;const sameLook=f.mat===g.mat&&!f.tag.includes('[');if(opts.visibleOnly&&sameLook)continue;
     if(opts.visibleOnly){/* both faces point down: bottoms resting on something, never seen */ if(n.y<-0.9)continue;
       /* centre of the overlap, 1 cm in front of the faces: inside another solid box -> hidden */
       const ov=(A,ha)=>{const d=tmp.dot(A),r=g.hu*Math.abs(g.u.dot(A))+g.hv*Math.abs(g.vv.dot(A));return (Math.max(-ha,d-r)+Math.min(ha,d+r))/2;};
       const P=f.c.clone().addScaledVector(f.u,ov(f.u,f.hu)).addScaledVector(f.vv,ov(f.vv,f.hv)).addScaledVector(n,0.01);
       const fb=f.tag,gb=g.tag;let hidden=false;for(const S of solids){if(S.tag===fb||S.tag===gb)continue;const dx=P.x-S.c.x,dy=P.y-S.c.y,dz=P.z-S.c.z;
         if(Math.abs(dx*S.a[0].x+dy*S.a[0].y+dz*S.a[0].z)<S.he[0]-0.002&&Math.abs(dx*S.a[1].x+dy*S.a[1].y+dz*S.a[1].z)<S.he[1]-0.002&&Math.abs(dx*S.a[2].x+dy*S.a[2].y+dz*S.a[2].z)<S.he[2]-0.002){hidden=true;break;}}
       if(hidden)continue;}hits.push({same:sameLook,ca:f.mat&&f.mat.color?f.mat.color.getHexString():'',cb:g.mat&&g.mat.color?g.mat.color.getHexString():'',a:f.tag,b:g.tag,area:+area.toFixed(3),at:[+f.c.x.toFixed(1),+f.c.y.toFixed(2),+f.c.z.toFixed(1)]});}}}
 hits.sort((x,y)=>y.area-x.area);return {boxes:nb,faces:faces.length,hits:hits.length,top:hits.slice(0,opts.top||12)};};0
