import * as THREE from 'three';
import {OrbitControls} from '/character/vendor/OrbitControls.js';
export class ModelPreview{
  constructor(element){
    this.element=element;this.scene=new THREE.Scene();this.camera=new THREE.PerspectiveCamera(32,1,.001,10000);
    this.renderer=new THREE.WebGLRenderer({antialias:true,alpha:true});this.renderer.setPixelRatio(Math.min(devicePixelRatio,2));this.renderer.outputColorSpace=THREE.SRGBColorSpace;
    element.append(this.renderer.domElement);this.controls=new OrbitControls(this.camera,this.renderer.domElement);this.controls.enableDamping=true;
    this.scene.add(new THREE.HemisphereLight(0xfff7e6,0x5b6b60,2.5));const key=new THREE.DirectionalLight(0xfff1d9,3);key.position.set(-3,5,4);this.scene.add(key);const fill=new THREE.DirectionalLight(0xcde6ef,1.5);fill.position.set(3,2,-3);this.scene.add(fill);
    this.group=new THREE.Group();this.scene.add(this.group);
    this.observer=new ResizeObserver(()=>{const rect=element.getBoundingClientRect();if(!rect.width||!rect.height)return;this.camera.aspect=rect.width/rect.height;this.camera.updateProjectionMatrix();this.renderer.setSize(rect.width,rect.height);});this.observer.observe(element);
    this.renderer.setAnimationLoop(()=>{this.controls.update();this.renderer.render(this.scene,this.camera);});
  }
  clear(){for(const mesh of [...this.group.children]){mesh.geometry.dispose();mesh.material.forEach(m=>m.dispose());this.group.remove(mesh);}}
  show(data){
    this.clear();for(const part of data.meshes){const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(part.positions,3));g.setAttribute('normal',new THREE.Float32BufferAttribute(part.normals,3));
      const indices=[];part.groups.forEach((group,i)=>{g.addGroup(indices.length,group.indices.length,i);for(const index of group.indices)indices.push(index);});g.setIndex(indices);
      const materials=part.groups.map(group=>new THREE.MeshStandardMaterial({color:new THREE.Color().setRGB(...group.material.color,THREE.SRGBColorSpace),roughness:.85}));this.group.add(new THREE.Mesh(g,materials));}
    const bounds=new THREE.Box3().setFromObject(this.group),center=bounds.getCenter(new THREE.Vector3()),size=bounds.getSize(new THREE.Vector3()).length();
    const distance=Math.max(.05,size/(2*Math.sin(THREE.MathUtils.degToRad(16))));this.controls.target.copy(center);this.camera.position.copy(center).add(new THREE.Vector3(.6,.3,-1).normalize().multiplyScalar(distance));this.camera.near=Math.max(.0001,size/1000);this.camera.far=Math.max(100,distance*10);this.camera.updateProjectionMatrix();this.controls.update();
  }
  dispose(){this.observer.disconnect();this.renderer.setAnimationLoop(null);this.clear();this.controls.dispose();this.renderer.dispose();this.renderer.domElement.remove();}
}
