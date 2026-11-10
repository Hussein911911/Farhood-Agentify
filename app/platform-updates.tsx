'use client';
import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

type Update = { id: string; title: string; body: string; published: boolean; created_at: string };

export function PlatformUpdatesAdmin() {
  const [items, setItems] = useState<Update[]>([]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

  const load = useCallback(async () => {
    if (!supabase) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('platform_updates')
      .select('id,title,body,published,created_at')
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) setError('تعذر تحميل تحديثات المنصة.');
    else setItems((data || []) as Update[]);
    setLoading(false);
  }, []);
  useEffect(() => { void load(); }, [load]);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase || busy) return;
    setBusy(true); setError(''); setMessage('');
    const { error } = await supabase.from('platform_updates').insert({ title: title.trim(), body: body.trim(), published: true });
    if (error) setError('تعذر نشر التحديث. تأكد من النص وأعد المحاولة.');
    else { setTitle(''); setBody(''); setMessage('تم نشر التحديث؛ يظهر الآن لكل مطاعم المنصة.'); await load(); }
    setBusy(false);
  }
  async function toggle(u: Update) {
    if (!supabase || busy) return;
    setBusy(true); setError(''); setMessage('');
    const { error } = await supabase.from('platform_updates').update({ published: !u.published }).eq('id', u.id);
    if (error) setError('تعذر تحديث حالة النشر.');
    else await load();
    setBusy(false);
  }
  async function remove(u: Update) {
    if (!supabase || busy) return;
    if (!window.confirm(`حذف التحديث «${u.title}» نهائياً؟`)) return;
    setBusy(true); setError(''); setMessage('');
    const { error } = await supabase.from('platform_updates').delete().eq('id', u.id);
    if (error) setError('تعذر حذف التحديث.');
    else await load();
    setBusy(false);
  }

  return (
    <section className="admin-card">
      <h2>تحديثات المنصة</h2>
      <p className="section-desc">التحديثات المنشورة تظهر لكل مطاعم المنصة داخل لوحة مدير المطعم. النشر لا يخص مطعماً بعينه ولا يرسل بريداً أو إشعاراً خارج اللوحة.</p>
      {error && <div className="error" role="alert">{error}</div>}
      {message && <div className="success" role="status">{message}</div>}
      <form className="admin-form" onSubmit={add}>
        <label>عنوان التحديث<input required maxLength={160} value={title} onChange={e => setTitle(e.target.value)} placeholder="مثلاً: ميزة جديدة متاحة" /></label>
        <label>النص<textarea required maxLength={2000} rows={3} value={body} onChange={e => setBody(e.target.value)} placeholder="وصف مختصر يظهر للمديرين" /></label>
        <button className="primary" disabled={busy || !title.trim() || !body.trim()}>{busy ? 'جاري الحفظ...' : 'نشر التحديث'}</button>
      </form>
      <div className="table-wrap">
        <table>
          <thead><tr><th>العنوان</th><th>النص</th><th>الحالة</th><th>التاريخ</th><th>إجراء</th></tr></thead>
          <tbody>
            {items.map(u => (
              <tr key={u.id}>
                <td><b>{u.title}</b></td>
                <td>{u.body}</td>
                <td><span className={'status ' + (u.published ? 'on' : 'pending')}><i />{u.published ? 'منشور' : 'مخفي'}</span></td>
                <td className="date">{new Date(u.created_at).toLocaleDateString('ar-IQ')}</td>
                <td>
                  <button className="text-action" disabled={busy} onClick={() => void toggle(u)}>{u.published ? 'إخفاء' : 'نشر'}</button>{' '}
                  <button className="text-action" disabled={busy} onClick={() => void remove(u)}>حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!items.length && <div className="empty">{loading ? 'جاري التحميل...' : 'ماكو تحديثات بعد.'}</div>}
      </div>
    </section>
  );
}
