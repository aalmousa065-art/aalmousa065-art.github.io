export const rawExtensions = /\.(arw|cr2|cr3|nef|nrw|dng|raf|rw2|orf|pef|srw|raw)$/i;
export function jpegRanges(bytes: Uint8Array): Array<[number, number]> {
 const results: Array<[number, number]> = [];
 for (let start=0;start<bytes.length-3;start++) {
  if(bytes[start]!==255||bytes[start+1]!==216||bytes[start+2]!==255)continue;
  let p=start+2,scan=false,valid=false;
  while(p<bytes.length-1){
   if(scan){while(p<bytes.length-1 && bytes[p]!==255)p++;}
   if(bytes[p++]!==255)break;
   while(bytes[p]===255)p++;
   const marker=bytes[p++];
   if(scan&&(marker===0||(marker>=208&&marker<=215)))continue;
   if(marker===217){valid=true;break;}
   if(marker===216||marker===undefined)break;
   if(marker===1)continue;
   const len=(bytes[p]<<8)|bytes[p+1];
   if(len<2||p+len>bytes.length)break;
   p+=len;scan=marker===218;
  }
  if(valid)results.push([start,p]);
 }
 return results.sort((a,b)=>(b[1]-b[0])-(a[1]-a[0]));
}
export function loadPreviewImage(blob: Blob): Promise<HTMLImageElement> {
 return new Promise((resolve,reject)=>{const url=URL.createObjectURL(blob);const image=new window.Image();image.onload=()=>{URL.revokeObjectURL(url);resolve(image)};image.onerror=()=>{URL.revokeObjectURL(url);reject(new Error('Cannot decode preview'))};image.src=url;});
}
export async function rawPreview(file: File, companion?: File): Promise<HTMLImageElement> {
 if(companion)return loadPreviewImage(companion);
 const bytes=new Uint8Array(await file.arrayBuffer());
 for(const [start,end] of jpegRanges(bytes).slice(0,12)){
  try{const image=await loadPreviewImage(new Blob([bytes.slice(start,end)],{type:'image/jpeg'}));if(Math.max(image.naturalWidth,image.naturalHeight)>=320)return image;}catch{/* Try the next embedded JPEG. */}
 }
 throw new Error(file.name+': no usable embedded JPG preview. Select a matching JPG in “Optional RAW preview” and try again.');
}
