/** Public read-only restaurant API. Never pass a Supabase secret/service-role key. */
export async function getRestaurantSite({projectUrl, publishableKey, slug, fetchImpl = fetch}) {
  const url = new URL(projectUrl);
  if (url.protocol !== 'https:' || !url.hostname.endsWith('.supabase.co') || url.username || url.password || url.port || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('رابط مشروع Supabase غير صالح.');
  }
  if (!publishableKey.startsWith('sb_publishable_')) throw new Error('استخدم مفتاح Supabase العام Publishable فقط.');
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) throw new Error('معرّف المطعم غير صالح.');
  const response = await fetchImpl(`${url.origin}/rest/v1/rpc/get_restaurant_site`, {
    method: 'POST', headers: {'Content-Type':'application/json', apikey: publishableKey},
    body: JSON.stringify({p_slug:slug}), cache:'no-store',
  });
  if (!response.ok) throw new Error('تعذر الاتصال بالمنصة.');
  const data = await response.json();
  if (!data || !['available','unavailable'].includes(data.status)) throw new Error('استجابة غير متوقعة من المنصة.');
  if (data.status === 'available' && (!Array.isArray(data.items) || typeof data.name !== 'string')) throw new Error('بيانات المطعم غير مكتملة.');
  return data;
}

/** Public read-only feed of published platform updates (no tenant data). */
export async function getPlatformUpdates({projectUrl, publishableKey, fetchImpl = fetch}) {
  const url = new URL(projectUrl);
  if (url.protocol !== 'https:' || !url.hostname.endsWith('.supabase.co') || url.username || url.password || url.port || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('رابط مشروع Supabase غير صالح.');
  }
  if (!publishableKey.startsWith('sb_publishable_')) throw new Error('استخدم مفتاح Supabase العام Publishable فقط.');
  const response = await fetchImpl(`${url.origin}/rest/v1/rpc/get_platform_updates`, {
    method: 'POST', headers: {'Content-Type':'application/json', apikey: publishableKey},
    body: '{}', cache: 'no-store',
  });
  if (!response.ok) throw new Error('تعذر الاتصال بالمنصة.');
  const data = await response.json();
  if (!Array.isArray(data) || data.some(u => !u || typeof u.title !== 'string' || typeof u.body !== 'string')) {
    throw new Error('استجابة غير متوقعة من المنصة.');
  }
  return data;
}
