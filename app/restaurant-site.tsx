'use client';
import {useEffect,useState} from 'react';
import {ArrowDown, MapPin, Phone, Clock3, UtensilsCrossed} from 'lucide-react';
import {supabase} from '../lib/supabase';
export type Food={name:string;description:string;category:string;price_iqd:number};
export type Site={status:string;name:string;headline:string;description:string;phone:string;address:string;hero_image_url:string;logo_url:string;opening_hours:string;accent_color:string;items:Food[]};
export function RestaurantSite({slug}:{slug:string}){
 const [data,setData]=useState<Site|null>(null),[loading,setLoading]=useState(true),[error,setError]=useState(false);
 useEffect(()=>{let alive=true;async function load(){if(!supabase){setError(true);setLoading(false);return;}const {data,error}=await supabase.rpc('get_restaurant_site',{p_slug:slug});if(alive){if(error)setError(true);else setData(data as Site);setLoading(false);}}void load();return()=>{alive=false}},[slug]);
 if(loading)return <div className="site-empty">جاري تحميل الموقع...</div>;
 if(error)return <div className="site-empty"><h1>تعذر تحميل الموقع</h1><p>حاول مرة ثانية لاحقاً.</p></div>;
 if(!data||data.status!=='available')return <div className="site-empty"><h1>الموقع غير متاح حالياً</h1><p>يرجى التواصل مع صاحب المطعم للمزيد من المعلومات.</p></div>;
 return <RestaurantSiteView data={data}/>;
}

export function RestaurantSiteView({data}:{data:Site}) {
 const categories=Array.from(new Set(data.items.map(i=>i.category)));const img=/^https:\/\//i.test(data.hero_image_url)?data.hero_image_url:'';const logo=/^https:\/\//i.test(data.logo_url)?data.logo_url:'';const phone=data.phone.replace(/[^+\d]/g,'');
 return <div className="restaurant-site" style={{'--accent':data.accent_color} as React.CSSProperties}><header className="site-header"><div className="site-logo">{logo?<img className="site-brand-image" src={logo} alt=""/>:<UtensilsCrossed size={20}/>}<strong>{data.name}</strong></div><nav><a href="#menu">المنيو</a><a href="#contact">تواصل ويانا</a></nav></header><section className="site-hero"><div className="site-hero-copy"><span className="site-tag">أهلاً وسهلاً بيكم</span><h1>{data.headline||`أهلاً بيكم في ${data.name}`}</h1><p>{data.description||'نكهات تحبّوها، ولمّة أحلى. ننتظركم بكل حب.'}</p><a className="site-button" href="#menu">اكتشف المنيو <ArrowDown size={17}/></a></div><div className="site-hero-image">{img?<img src={img} alt=""/>:<div className="site-image-placeholder"><UtensilsCrossed size={62}/><span>أهلاً بيكم في {data.name}</span></div>}</div></section><section id="menu" className="site-menu"><div className="site-section-head"><span>من مطبخنا إلكم</span><h2>منيو المطعم</h2><p>اختار اللي يعجبك من أصنافنا</p></div>{categories.length?categories.map(c=><div className="site-category" key={c}><h3>{c}</h3><div className="site-items">{data.items.filter(i=>i.category===c).map((item,index)=><div className="site-item" key={index}><div><h4>{item.name}</h4>{item.description&&<p>{item.description}</p>}</div><b>{Number(item.price_iqd).toLocaleString('ar-IQ')} د.ع</b></div>)}</div></div>):<p className="site-no-menu">المنيو قريباً.</p>}</section><section id="contact" className="site-contact"><div><span>ننتظركم بكل حب</span><h2>تواصل ويانا</h2><p>نسعد بزيارتكم وتواصلكم ويا {data.name}.</p></div><div className="site-contact-info">{data.address&&<p><MapPin size={18}/> {data.address}</p>}{data.opening_hours&&<p><Clock3 size={18}/> {data.opening_hours}</p>}{phone&&<p><Phone size={18}/> <a dir="ltr" href={`tel:${phone}`}>{data.phone}</a></p>}</div></section><footer className="site-footer">{data.name} · Powered by Farhood Agentify</footer></div>;
}
