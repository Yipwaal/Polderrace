window.__zfight=(root,opts)=>{opts=opts||{};const faces=[],m4=new THREE.Matrix4(),im=new THREE.Matrix4(),v=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();
 const ax=[new THREE.Vector3(),new THREE.Vector3(),new THREE.Vector3()];let nb=0;const solids=[];
 const addBox=(M,w,h,d,mat,tag)=>{M.decompose(v,q,s);if(Math.abs(s.x*s.y*s.z)<1e-9)return;const he=[w*s.x/2,h*s.y/2,d*s.z/2];ax[0].set(1,0,0).applyQuaternion(q);ax[1].set(0,1,0).applyQuaternion(q);ax[2].set(0,0,1).applyQuaternion(q);nb++;
   if(!(mat&&mat.transparent))solids.push({c:v.clone(),a:[ax[0].clone(),ax[1].clone(),ax[2].clone()],he:he.slice(),tag});
   for(let a=0;a<3;a++)for(const sg of [-1,1]){const n=ax[a].clone().multiplyScalar(sg),c=v.clone().addScaledVector(ax[a],sg*he[a]),b=(a+1)%3,e=(a+2)%3;
     faces.push({n,c,u:ax[b].clone(),vv:ax[e].clone(),hu:he[b],hv:he[e],mat,tag});}};
 const addPlane=(M,w,h,mat,tag)=>{M.decompose(v,q,s);const n=new THREE.Vector3(0,0,1).applyQuaternion(q),u=new THREE.Vector3(1,0,0).applyQuaternion(q),vv=new THREE.Vector3(0,1,0).applyQuaternion(q);
   faces.push({n,c:v.clone(),u,vv,hu:w*s.x/2,hv:h*s.y/2,mat,tag,plane:true});if(mat&&mat.side===THREE.DoubleSide)faces.push({n:n.clone().negate(),c:v.clone(),u,vv,hu:w*s.x/2,hv:h*s.y/2,mat,tag,plane:true});};
 /* the game's inst() clones the geometry, and in three r128 a clone is a plain BufferGeometry (no type, no parameters):
    with opts.inst (test_zfight sets it by default) a box is recognised by its shape instead (24 vertices, 36 indices, every vertex on a corner of its bounding box) */
 const bl=new Map(),bb=new THREE.Box3(),bs=new THREE.Vector3(),bc=new THREE.Vector3();
 const boxLike=g=>{if(bl.has(g))return bl.get(g);let r=null;const pa=g.attributes.position;
   if(pa&&pa.count===24&&g.index&&g.index.count===36){bb.setFromBufferAttribute(pa);let ok=true;
     for(let i=0;i<24&&ok;i++)for(const [c,a,b] of [[pa.getX(i),bb.min.x,bb.max.x],[pa.getY(i),bb.min.y,bb.max.y],[pa.getZ(i),bb.min.z,bb.max.z]])if(Math.abs(c-a)>1e-5&&Math.abs(c-b)>1e-5)ok=false;
     if(ok){bb.getSize(bs);bb.getCenter(bc);r={w:bs.x,h:bs.y,d:bs.z,t:new THREE.Matrix4().makeTranslation(bc.x,bc.y,bc.z)};}}
   bl.set(g,r);return r;};
 root.updateMatrixWorld(true);
 root.traverse(o=>{if(!o.isMesh||!o.visible)return;let vis=true;o.traverseAncestors(a=>{if(!a.visible)vis=false;});if(!vis)return;const p=o.geometry.parameters||{},t=o.geometry.type;
   const tag=(o.name||t)+'#'+o.id;const mats=Array.isArray(o.material)?o.material[4]:o.material;
   if(o.isInstancedMesh){const bx=t==='BoxGeometry'||!opts.inst?null:boxLike(o.geometry);for(let k=0;k<o.count;k++){o.getMatrixAt(k,im);m4.multiplyMatrices(o.matrixWorld,im);if(t==='BoxGeometry')addBox(m4,p.width,p.height,p.depth,mats,tag+'['+k+']');else if(bx){m4.multiply(bx.t);addBox(m4,bx.w,bx.h,bx.d,mats,tag+'['+k+']');}else if(t==='PlaneGeometry')addPlane(m4,p.width,p.height,mats,tag+'['+k+']');}}
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
/* triangle version for curved/merged geometry (the lofted car bodies, lathed tyres, merged detail sets): every triangle of every visible mesh
   becomes a face; two faces flicker when they point the same way, lie within 4 mm of one plane, overlap by more than 5 mm in that plane and
   belong to different materials (the same material on both sides shades identically, so that cannot be seen) */
window.__zfTris=(root,opts)=>{opts=opts||{};const F=[],a=new THREE.Vector3(),b=new THREE.Vector3(),c=new THREE.Vector3(),e1=new THREE.Vector3(),e2=new THREE.Vector3();
 root.updateMatrixWorld(true);
 root.traverse(o=>{if(!o.isMesh||o.isInstancedMesh||!o.visible)return;let vis=true;o.traverseAncestors(q=>{if(!q.visible)vis=false;});if(!vis)return;
   const g=o.geometry,pa=g.attributes.position;if(!pa)return;const idx=g.index,nt=(idx?idx.count:pa.count)/3,mats=Array.isArray(o.material)?o.material:null;
   const groups=g.groups&&g.groups.length?g.groups:[{start:0,count:nt*3,materialIndex:0}],flip=o.matrixWorld.determinant()<0; /* mirrored: three draws the other winding as front */
   for(const gr of groups){const mat=mats?mats[gr.materialIndex]:o.material;if(!mat||mat.transparent||mat.visible===false)continue;
     for(let t=gr.start/3;t<(gr.start+gr.count)/3;t++){const i0=idx?idx.getX(3*t):3*t,i1=idx?idx.getX(3*t+1):3*t+1,i2=idx?idx.getX(3*t+2):3*t+2;
       a.fromBufferAttribute(pa,i0).applyMatrix4(o.matrixWorld);b.fromBufferAttribute(pa,i1).applyMatrix4(o.matrixWorld);c.fromBufferAttribute(pa,i2).applyMatrix4(o.matrixWorld);
       e1.subVectors(b,a);e2.subVectors(c,a);const n=new THREE.Vector3().crossVectors(e1,e2),ar=n.length()/2;if(flip)n.negate();if(ar<1e-5)continue;n.normalize();
       F.push({n,p:[a.clone(),b.clone(),c.clone()],c:a.clone().add(b).add(c).divideScalar(3),mat,tag:o.id+'/'+gr.materialIndex,area:ar});}}});
 const H=new Map(),key=(n,d)=>[Math.round(n.x*20),Math.round(n.y*20),Math.round(n.z*20),d].join(',');
 for(const f of F){const d=Math.round(f.n.dot(f.c)/0.01);f.d=d;const k=key(f.n,d);if(!H.has(k))H.set(k,[]);H.get(k).push(f);}
 const axes=(f,g)=>{const r=[];for(const P of [f.p,g.p])for(let i=0;i<P.length;i++)r.push(new THREE.Vector3().subVectors(P[(i+1)%P.length],P[i]).cross(f.n).normalize());return r;};
 const hits=[];
 for(const f of F){for(const dd of [-1,0,1]){const L=H.get(key(f.n,f.d+dd));if(!L)continue;for(const g of L){if(g===f||g.tag===f.tag||(dd===0&&g.tag<f.tag))continue;
     if(f.mat===g.mat||(f.mat.color&&g.mat.color&&f.mat.color.equals(g.mat.color)&&f.mat.type===g.mat.type&&!f.mat.map&&!g.mat.map))continue;
     if(f.n.dot(g.n)<0.999||Math.abs(f.n.dot(g.c)-f.n.dot(f.c))>0.004)continue;
     let sep=false,ovMin=1e9;for(const A of axes(f,g)){let a0=1e9,a1=-1e9,b0=1e9,b1=-1e9;for(const p of f.p){const v=p.dot(A);a0=Math.min(a0,v);a1=Math.max(a1,v);}for(const p of g.p){const v=p.dot(A);b0=Math.min(b0,v);b1=Math.max(b1,v);}
       const ov=Math.min(a1,b1)-Math.max(a0,b0);if(ov<=0.005){sep=true;break;}ovMin=Math.min(ovMin,ov);}
     if(sep)continue;hits.push({ca:f.mat.color?f.mat.color.getHexString():'',cb:g.mat.color?g.mat.color.getHexString():'',a:f.tag,b:g.tag,ov:+ovMin.toFixed(3),at:[+f.c.x.toFixed(2),+f.c.y.toFixed(2),+f.c.z.toFixed(2)]});}}}
 return {tris:F.length,hits:hits.length,top:hits.slice(0,opts.top||8)};};0
