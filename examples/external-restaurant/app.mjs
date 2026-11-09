import {getRestaurantSite} from './farhood-api.mjs';
const $ = id => document.getElementById(id);
const form = $('settings'), status = $('status'), site = $('site'), button = form.querySelector('button');
function text(id,value){$(id).textContent=value||'';}
function showMenu(items){
 const container=$('items');container.replaceChildren();
 if(!items.length){const p=document.createElement('p');p.textContent='المنيو قريباً.';container.append(p);return;}
 const groups=new Map();for(const item of items){const key=typeof item.category==='string'?item.category:'المنيو';if(!groups.has(key))groups.set(key,[]);groups.get(key).push(item);}
 for(const [category,rows] of groups){const section=document.createElement('section'),heading=document.createElement('h3'),grid=document.createElement('div');heading.textContent=category;grid.className='menu-grid';section.append(heading,grid);for(const item of rows){const card=document.createElement('article'),info=document.createElement('div'),title=document.createElement('h4'),description=document.createElement('p'),price=document.createElement('strong');title.textContent=item.name||'';description.textContent=item.description||'';price.textContent=`${Number(item.price_iqd).toLocaleString('ar-IQ')} د.ع`;info.append(title,description);card.append(info,price);grid.append(card);}container.append(section);}
}
form.addEventListener('submit',async event=>{event.preventDefault();site.hidden=true;status.textContent='جاري تحميل الموقع...';button.disabled=true;try{const data=await getRestaurantSite({projectUrl:$('project').value.trim(),publishableKey:$('key').value.trim(),slug:$('slug').value.trim()});if(data.status==='unavailable'){status.textContent='الموقع غير متاح حالياً. تحقق من النشر والاشتراك ومعرّف المطعم.';return;}text('name',data.name);text('headline',data.headline);text('description',data.description);text('address',data.address);text('hours',data.opening_hours);text('phone',data.phone);showMenu(data.items);status.textContent='';site.hidden=false;}catch(error){status.textContent=error instanceof Error?error.message:'تعذر تحميل الموقع.';}finally{button.disabled=false;}});
