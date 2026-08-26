(() => {
  'use strict';
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const cfg = window.CALISLEVEL_CONFIG || {};
  const badCfg = !cfg.SUPABASE_URL || !cfg.SUPABASE_PUBLISHABLE_KEY || cfg.SUPABASE_URL.includes('TWOJ-PROJEKT') || cfg.SUPABASE_PUBLISHABLE_KEY.includes('TU_WKLEJ');
  if (badCfg || !window.supabase) {
    $('#setupScreen').classList.remove('hidden');
    return;
  }

  const db = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });

  const state = {
    user: null, profile: null, settings: null, exercises: [], plans: [], skills: [], leaderboard: [],
    activeWorkout: null, sessionTicker: null, restTimer: null, restSeconds: 0,
    pickerCallback: null, rankMode: 'score', selectedPlanExercises: []
  };

  const rankName = level => {
    const r = [[1,'Bronze III'],[3,'Bronze II'],[5,'Bronze I'],[7,'Silver III'],[10,'Silver II'],[13,'Silver I'],[16,'Gold III'],[20,'Gold II'],[24,'Gold I'],[28,'Platinum'],[34,'Diamond'],[40,'Master'],[50,'Legend']];
    let out='Bronze III'; for (const [l,n] of r) if (level>=l) out=n; return out;
  };
  const levelInfo = xp => { let level=1, rem=+xp||0, need=100; while(rem>=need){rem-=need; level++; need=Math.round(100*Math.pow(1.14,level-1));} return {level,rem,need,pct:Math.min(100,rem/need*100)}; };
  const todayISO = () => new Date().toISOString().slice(0,10);
  const mondayIndex = d => { const x=d.getDay(); return x===0?7:x; };
  const esc = s => String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  const num = v => Number(v||0);
  const fmt = n => new Intl.NumberFormat('pl-PL',{maximumFractionDigits:1}).format(n||0);
  const toast = msg => { const t=$('#toast'); t.textContent=msg; t.classList.add('show'); clearTimeout(t._x); t._x=setTimeout(()=>t.classList.remove('show'),2600); };
  async function q(promise, quiet=false){ const {data,error}=await promise; if(error){console.error(error); if(!quiet) toast(error.message||'Błąd'); throw error;} return data; }

  function go(screen){
    $$('.screen').forEach(s=>s.classList.toggle('active',s.dataset.screen===screen));
    $$('.bottom-nav button').forEach(b=>b.classList.toggle('active',b.dataset.go===screen));
    if(screen==='ranking') loadLeaderboard();
    if(screen==='calendar') loadCalendar();
    if(screen==='nutrition') loadNutrition();
    if(screen==='supplements') loadSupplements();
    if(screen==='progress') loadProgress();
    if(screen==='exercises') renderExerciseLibrary();
    if(screen==='profile') renderProfile();
    window.scrollTo({top:0,behavior:'smooth'});
  }
  $$('[data-go]').forEach(b=>b.addEventListener('click',()=>go(b.dataset.go)));
  $('#profileButton').addEventListener('click',()=>go('profile'));

  // AUTH
  $$('[data-auth-tab]').forEach(b=>b.addEventListener('click',()=>{
    $$('[data-auth-tab]').forEach(x=>x.classList.toggle('active',x===b));
    $('#loginForm').classList.toggle('hidden',b.dataset.authTab!=='login');
    $('#registerForm').classList.toggle('hidden',b.dataset.authTab!=='register');
  }));
  $('#loginForm').addEventListener('submit',async e=>{
    e.preventDefault();
    try{ await q(db.auth.signInWithPassword({email:$('#loginEmail').value.trim(),password:$('#loginPassword').value})); toast('Zalogowano'); }catch{}
  });
  $('#registerForm').addEventListener('submit',async e=>{
    e.preventDefault();
    try{
      const email=$('#registerEmail').value.trim(), password=$('#registerPassword').value;
      await q(db.auth.signUp({email,password,options:{data:{username:$('#registerUsername').value.trim(),display_name:$('#registerName').value.trim()}}}));
      toast('Konto utworzone. Jeśli Supabase wymaga potwierdzenia e-mail, sprawdź skrzynkę.');
    }catch{}
  });
  $('#logoutBtn').addEventListener('click',async()=>{await db.auth.signOut();});
  db.auth.onAuthStateChange((_event,session)=>setSession(session));

  async function setSession(session){
    state.user=session?.user||null;
    $('#authScreen').classList.toggle('hidden',!!state.user);
    $('#app').classList.toggle('hidden',!state.user);
    if(state.user) await bootstrap();
  }

  async function bootstrap(){
    try{
      const uid=state.user.id;
      const [profile,settings,exercises,skills,seasons] = await Promise.all([
        q(db.from('profiles').select('*').eq('id',uid).single()),
        q(db.from('user_settings').select('*').eq('user_id',uid).single()),
        q(db.from('exercises').select('*').order('category').order('name').limit(1000)),
        q(db.from('skill_definitions').select('*').order('name')),
        q(db.from('seasons').select('*').eq('active',true).lte('starts_on',todayISO()).gte('ends_on',todayISO()).limit(1),true)
      ]);
      state.profile=profile; state.settings=settings; state.exercises=exercises||[]; state.skills=skills||[];
      $('#profileName').textContent=profile.display_name; $('#profileInitial').textContent=(profile.display_name||'?')[0].toUpperCase();
      if(seasons?.[0]) $('#headerSeason').textContent=seasons[0].name.toUpperCase();
      state.activeWorkout=JSON.parse(localStorage.getItem('calislevel-active-'+uid)||'null');
      await Promise.all([loadPlans(),loadHome()]);
      renderWorkout();
      if(state.activeWorkout) startSessionTicker();
    }catch(e){console.error(e)}
  }

  async function loadHome(){
    const uid=state.user.id;
    const weekStart=new Date(); const day=mondayIndex(weekStart); weekStart.setDate(weekStart.getDate()-day+1); weekStart.setHours(0,0,0,0);
    const [stats,weekWorkouts,todayEvents,todaySupp,measurements] = await Promise.all([
      q(db.from('leaderboard_stats').select('*').eq('user_id',uid).single(),true),
      q(db.from('workouts').select('id').eq('user_id',uid).not('finished_at','is',null).gte('started_at',weekStart.toISOString()),true),
      q(db.from('calendar_events').select('*,plans(name)').eq('user_id',uid).eq('event_date',todayISO()).order('event_time'),true),
      getTodaySupplementRows(),
      q(db.from('measurements').select('*').eq('user_id',uid).order('measured_on',{ascending:false}).limit(1),true)
    ]);
    const st=stats||{lifetime_xp:0,calis_score:0,current_streak:0,workout_count:0}; const li=levelInfo(st.lifetime_xp);
    $('#homeScore').textContent=fmt(st.calis_score); $('#homeLevel').textContent=li.level; $('#homeRank').textContent=rankName(li.level); $('#homeXP').textContent=`${fmt(st.lifetime_xp)} XP`; $('#xpBar').style.width=li.pct+'%';
    $('#homeWeek').textContent=`${weekWorkouts?.length||0}/${state.settings.weekly_goal||2}`; $('#homeStreak').textContent=st.current_streak||0; $('#homeWorkouts').textContent=st.workout_count||0;
    renderTodayAgenda(todayEvents||[],todaySupp||[],measurements?.[0]);
    renderNextPlan();
    await loadLeaderboard(true);
  }

  function renderTodayAgenda(events,supps,lastMeasurement){
    const rows=[];
    events.forEach(e=>rows.push(`<div class="card"><div class="row"><div><b>${e.kind==='training'?'🏋️':e.kind==='measurement'?'📏':'📅'} ${esc(e.title)}</b><small class="muted">${e.event_time?e.event_time.slice(0,5):'dzisiaj'}${e.plans?.name?' • '+esc(e.plans.name):''}</small></div><span>${e.completed?'✓':''}</span></div></div>`));
    supps.slice(0,3).forEach(s=>rows.push(`<div class="card"><div class="row"><div><b>💊 ${esc(s.supplements.name)}</b><small class="muted">${s.supplements.dose??''} ${esc(s.supplements.unit||'')} ${s.time_of_day?('• '+s.time_of_day.slice(0,5)):''}</small></div><span>${s.taken?'✓':''}</span></div></div>`));
    if(!rows.length) rows.push('<div class="card"><b>Spokojny dzień</b><p class="muted">Brak zaplanowanych wpisów. Możesz dodać trening w kalendarzu.</p></div>');
    $('#todayAgenda').innerHTML=rows.join('');
  }

  // PLANS
  async function loadPlans(){ state.plans=await q(db.from('plans').select('*,plan_exercises(*,exercises(*))').eq('user_id',state.user.id).order('created_at'))||[]; renderPlans(); renderNextPlan(); }
  function renderNextPlan(){
    const p=state.plans[0];
    $('#nextPlanCard').innerHTML=p?`<div class="plan-head"><div><h3>${esc(p.name)}</h3><small class="muted">${esc(p.description||'')}</small></div><span class="tag">${p.plan_exercises?.length||0} ćw.</span></div><div class="tags">${(p.plan_exercises||[]).slice(0,5).map(x=>`<span class="tag">${esc(x.exercises?.name||'')}</span>`).join('')}</div><button class="primary full" onclick="Calis.startPlan('${p.id}')">Start</button>`:'<p class="muted">Nie masz jeszcze planu. Dodaj 3 gotowe albo stwórz własny.</p>';
  }
  function renderPlans(){
    $('#plansList').innerHTML=state.plans.length?state.plans.map(p=>`<div class="card plan-card"><div class="plan-head"><div><h3>${esc(p.name)}</h3><small class="muted">${esc(p.description||'')}</small></div><span class="tag">${p.plan_exercises?.length||0} ćw.</span></div><div class="tags">${(p.plan_exercises||[]).slice(0,6).map(x=>`<span class="tag">${esc(x.exercises?.name||'')} • ${x.sets}×${x.rep_min||''}${x.rep_max?'–'+x.rep_max:''}</span>`).join('')}</div><div class="plan-actions"><button class="primary" onclick="Calis.startPlan('${p.id}')">Start</button><button class="secondary" onclick="Calis.editPlan('${p.id}')">Edytuj</button><button class="danger ghost" onclick="Calis.deletePlan('${p.id}')">✕</button></div></div>`).join(''):'<div class="empty"><div>▦</div><h3>Brak planów</h3><p>Stwórz własny plan z pełnej biblioteki ćwiczeń.</p></div>';
  }
  $('#createPlanBtn').addEventListener('click',()=>openPlanEditor());
  $('#installTemplatesBtn').addEventListener('click',installAthleticTemplates);

  const TEMPLATES=[
    {name:'Calis Athletic A',description:'Pull + Push + Legs',items:[['podciaganie-nachwyt-sredni-masa-ciala',4,4,8,120],['bar-dip',4,5,10,120],['przysiad-back-squat-high-bar',3,6,10,150],['wioslowanie-maszyna-chest-supported-standard',3,8,12,100],['unoszenie-bokiem-hantle-oburacz',3,12,20,60],['hanging-leg-raise',3,8,15,75],['tyl-barkow-face-pull-linka',2,15,20,60]]},
    {name:'Calis Athletic B',description:'Shoulders + Pull + Posterior',items:[['podciaganie-podchwyt-masa-ciala',4,5,10,120],['wyciskanie-nad-glowe-hantle-siedzac',3,6,10,120],['rdl-sztanga',3,6,10,150],['pompki-klasyczne',3,8,15,75],['sciaganie-drazka-wyciagu-waski-neutralny',3,8,12,100],['unoszenie-bokiem-hantle-oburacz',3,12,20,60],['ab-wheel-rollout',3,6,12,90],['farmer-carry',2,null,null,90]]},
    {name:'Calis Athletic C',description:'Skills + Athletic Full Body',items:[['muscle-up-na-drazku',4,1,5,150],['elevated-pike-push-up',4,6,12,90],['bulgarian-split-squat-hantle',3,8,12,90],['podciaganie-neutralny-z-guma',3,8,12,90],['l-sit',4,null,null,90],['hollow-body-hold',3,null,null,60],['unoszenie-bokiem-hantle-oburacz',3,12,20,60]]}
  ];
  async function installAthleticTemplates(){
    if(!confirm('Dodać 3 gotowe plany Calis Athletic do Twojego konta?')) return;
    for(const t of TEMPLATES){
      if(state.plans.some(p=>p.name===t.name)) continue;
      const plan=await q(db.from('plans').insert({user_id:state.user.id,name:t.name,description:t.description}).select().single());
      const inserts=[]; let order=0;
      for(const [slug,sets,rmin,rmax,rest] of t.items){ const ex=state.exercises.find(e=>e.slug===slug); if(ex) inserts.push({plan_id:plan.id,exercise_id:ex.id,sort_order:order++,sets,rep_min:rmin,rep_max:rmax,rest_sec:rest}); }
      if(inserts.length) await q(db.from('plan_exercises').insert(inserts));
    }
    toast('Dodano 3 plany'); await loadPlans();
  }

  function openPlanEditor(plan=null){
    state.selectedPlanExercises = plan ? (plan.plan_exercises||[]).sort((a,b)=>a.sort_order-b.sort_order).map(x=>({exercise_id:x.exercise_id,exercise:x.exercises,sets:x.sets,rep_min:x.rep_min,rep_max:x.rep_max,rest_sec:x.rest_sec})) : [];
    const exerciseOptions=[...state.exercises].sort((a,b)=>a.category.localeCompare(b.category,'pl')||a.name.localeCompare(b.name,'pl')).map(ex=>`<option value="${esc(ex.id)}">${esc(ex.category)} — ${esc(ex.name)}</option>`).join('');
    openModal(plan?'Edytuj plan':'Nowy plan',()=>savePlan(plan?.id),`<label>Nazwa<input id="mPlanName" value="${esc(plan?.name||'')}"></label><label>Opis<input id="mPlanDesc" value="${esc(plan?.description||'')}"></label><div id="mPlanItems"></div><label>Ćwiczenie<select id="mPlanExercise"><option value="">— Wybierz ćwiczenie z listy —</option>${exerciseOptions}</select></label><button type="button" class="secondary full" id="mAddPlanExercise">+ Dodaj wybrane ćwiczenie</button>`);
    renderPlanModalItems(); $('#mAddPlanExercise').onclick=()=>{const select=$('#mPlanExercise'),ex=state.exercises.find(item=>item.id===select.value);if(!ex){toast('Wybierz ćwiczenie z listy');return;}state.selectedPlanExercises.push({exercise_id:ex.id,exercise:ex,sets:3,rep_min:8,rep_max:12,rest_sec:90});select.value='';renderPlanModalItems();};
  }
  function renderPlanModalItems(){ const box=$('#mPlanItems'); if(!box)return; box.innerHTML=state.selectedPlanExercises.map((x,i)=>`<div class="exercise-card"><div class="row"><b>${esc(x.exercise.name)}</b><button type="button" class="danger ghost" onclick="Calis.removePlanItem(${i})">✕</button></div><div class="form-grid"><label>Serie<input type="number" value="${x.sets}" onchange="Calis.planField(${i},'sets',this.value)"></label><label>Min powt.<input type="number" value="${x.rep_min??''}" onchange="Calis.planField(${i},'rep_min',this.value)"></label><label>Max powt.<input type="number" value="${x.rep_max??''}" onchange="Calis.planField(${i},'rep_max',this.value)"></label><label>Przerwa s<input type="number" value="${x.rest_sec}" onchange="Calis.planField(${i},'rest_sec',this.value)"></label></div></div>`).join(''); }
  async function savePlan(id){
    const name=$('#mPlanName').value.trim(); if(!name){toast('Podaj nazwę');return false;}
    let planId=id;
    if(id){ await q(db.from('plans').update({name,description:$('#mPlanDesc').value.trim(),updated_at:new Date().toISOString()}).eq('id',id)); await q(db.from('plan_exercises').delete().eq('plan_id',id)); }
    else { const p=await q(db.from('plans').insert({user_id:state.user.id,name,description:$('#mPlanDesc').value.trim()}).select().single()); planId=p.id; }
    if(state.selectedPlanExercises.length) await q(db.from('plan_exercises').insert(state.selectedPlanExercises.map((x,i)=>({plan_id:planId,exercise_id:x.exercise_id,sort_order:i,sets:+x.sets||3,rep_min:x.rep_min?+x.rep_min:null,rep_max:x.rep_max?+x.rep_max:null,rest_sec:+x.rest_sec||90}))));
    await loadPlans(); return true;
  }
  async function deletePlan(id){if(confirm('Usunąć plan?')){await q(db.from('plans').delete().eq('id',id));await loadPlans();}}

  // WORKOUT SESSION
  function saveActive(){ if(state.user) localStorage.setItem('calislevel-active-'+state.user.id,JSON.stringify(state.activeWorkout)); }
  function startPlan(id){ const p=state.plans.find(x=>x.id===id); if(!p)return; state.activeWorkout={id:crypto.randomUUID(),plan_id:p.id,title:p.name,started_at:new Date().toISOString(),exercises:(p.plan_exercises||[]).sort((a,b)=>a.sort_order-b.sort_order).map(x=>({exercise:x.exercises,exercise_id:x.exercise_id,rest_sec:x.rest_sec||90,sets:Array.from({length:x.sets},()=>({weight:'',reps:'',rpe:'',duration:'',done:false}))}))}; saveActive(); renderWorkout(); startSessionTicker(); go('workout'); }
  $('#quickWorkout').addEventListener('click',()=>{state.activeWorkout={id:crypto.randomUUID(),plan_id:null,title:'Pusty trening',started_at:new Date().toISOString(),exercises:[]};saveActive();renderWorkout();startSessionTicker();});
  $('#addExerciseSession').addEventListener('click',()=>openExercisePicker(ex=>{state.activeWorkout.exercises.push({exercise:ex,exercise_id:ex.id,rest_sec:90,sets:[{weight:'',reps:'',rpe:'',duration:'',done:false},{weight:'',reps:'',rpe:'',duration:'',done:false},{weight:'',reps:'',rpe:'',duration:'',done:false}]});saveActive();renderWorkout();}));
  $('#discardWorkout').addEventListener('click',()=>{if(state.activeWorkout&&confirm('Usunąć aktywny trening?')){state.activeWorkout=null;saveActive();renderWorkout();}});
  $('#finishWorkout').addEventListener('click',finishWorkout);
  function renderWorkout(){
    const a=state.activeWorkout; $('#workoutEmpty').classList.toggle('hidden',!!a); $('#workoutActive').classList.toggle('hidden',!a); if(!a)return;
    $('#workoutTitle').textContent=a.title;
    $('#sessionExercises').innerHTML=a.exercises.map((e,ei)=>`<div class="exercise-card"><div class="exercise-head"><div><h3>${esc(e.exercise.name)}</h3><small>${esc(e.exercise.category)}</small></div><button class="secondary compact" onclick="Calis.startRest(${e.rest_sec||90})">⏱ ${e.rest_sec||90}s</button></div><div class="sets-head"><span>#</span><span>kg/+kg</span><span>powt.</span><span>RPE</span><span>✓</span></div>${e.sets.map((s,si)=>`<div class="set-row"><span>${si+1}</span><input type="number" step="0.5" value="${s.weight}" oninput="Calis.setVal(${ei},${si},'weight',this.value)"><input type="number" value="${s.reps}" oninput="Calis.setVal(${ei},${si},'reps',this.value)"><input type="number" step="0.5" min="1" max="10" value="${s.rpe}" oninput="Calis.setVal(${ei},${si},'rpe',this.value)"><input type="checkbox" ${s.done?'checked':''} onchange="Calis.doneSet(${ei},${si},this.checked)"></div>`).join('')}<button class="add-set" onclick="Calis.addSet(${ei})">+ seria</button></div>`).join(''); updateSessionStats();
  }
  function setVal(ei,si,k,v){state.activeWorkout.exercises[ei].sets[si][k]=v;saveActive();updateSessionStats();}
  function doneSet(ei,si,v){const e=state.activeWorkout.exercises[ei];e.sets[si].done=v;saveActive();updateSessionStats();if(v)startRest(e.rest_sec||90);}
  function addSet(ei){state.activeWorkout.exercises[ei].sets.push({weight:'',reps:'',rpe:'',duration:'',done:false});saveActive();renderWorkout();}
  function sessionVolume(){let v=0;for(const e of state.activeWorkout?.exercises||[])for(const s of e.sets)if(s.done)v+=num(s.weight)*num(s.reps);return v;}
  function updateSessionStats(){if(!state.activeWorkout)return; $('#sessionVolume').textContent=fmt(sessionVolume())+' kg'; $('#sessionSets').textContent=state.activeWorkout.exercises.reduce((a,e)=>a+e.sets.filter(s=>s.done).length,0);}
  function startSessionTicker(){clearInterval(state.sessionTicker);const tick=()=>{if(!state.activeWorkout)return;const s=Math.floor((Date.now()-new Date(state.activeWorkout.started_at))/1000);$('#sessionTimer').textContent=String(Math.floor(s/60)).padStart(2,'0')+':'+String(s%60).padStart(2,'0');};tick();state.sessionTicker=setInterval(tick,1000);}
  async function finishWorkout(){
    const a=state.activeWorkout; if(!a)return; const done=a.exercises.flatMap(e=>e.sets.filter(s=>s.done).map((s,i)=>({e,s,i}))); if(!done.length){toast('Zaznacz wykonane serie');return;}
    try{
      const workout=await q(db.from('workouts').insert({user_id:state.user.id,plan_id:a.plan_id,title:a.title,started_at:a.started_at}).select().single());
      const sets=[]; for(const e of a.exercises){let no=1;for(const s of e.sets){if(s.done)sets.push({workout_id:workout.id,exercise_id:e.exercise_id,set_no:no++,weight_kg:s.weight?+s.weight:null,reps:s.reps?+s.reps:null,rpe:s.rpe?+s.rpe:null,completed:true});}}
      await q(db.from('workout_sets').insert(sets));
      await q(db.from('workouts').update({finished_at:new Date().toISOString(),duration_seconds:Math.floor((Date.now()-new Date(a.started_at))/1000)}).eq('id',workout.id));
      state.activeWorkout=null; saveActive(); clearInterval(state.sessionTicker); toast('Trening zapisany • +50 XP'); await Promise.all([loadPlans(),loadHome()]);renderWorkout();go('home');
    }catch(e){}
  }

  // EXERCISE LIBRARY / PICKER
  const categories=()=>[...new Set(state.exercises.map(e=>e.category))].sort(); let exerciseCategory='Wszystkie';
  function renderExerciseLibrary(){
    $('#exerciseFilters').innerHTML=['Wszystkie',...categories()].slice(0,18).map(c=>`<button class="chip ${c===exerciseCategory?'active':''}" onclick="Calis.setExerciseCategory('${esc(c)}')">${esc(c)}</button>`).join('');
    const term=($('#exerciseSearch').value||'').toLowerCase(); const list=state.exercises.filter(e=>(exerciseCategory==='Wszystkie'||e.category===exerciseCategory)&&(!term||(`${e.name} ${e.category} ${e.equipment||''}`).toLowerCase().includes(term))).slice(0,120);
    $('#exerciseList').innerHTML=list.map(e=>`<div class="list-row"><div><b>${esc(e.name)}</b><small>${esc(e.category)} • ${esc(e.equipment||'')}</small></div>${e.owner_id?'<span class="tag">własne</span>':''}</div>`).join('')||'<p class="muted">Brak wyników.</p>';
  }
  $('#exerciseSearch').addEventListener('input',renderExerciseLibrary); $('#customExerciseBtn').addEventListener('click',()=>openCustomExercise());
  function setExerciseCategory(c){exerciseCategory=c;renderExerciseLibrary();}
  function openExercisePicker(cb){state.pickerCallback=cb;$('#pickerSearch').value='';renderPicker('');$('#pickerModal').showModal();}
  function renderPicker(term){term=term.toLowerCase();$('#pickerResults').innerHTML=state.exercises.filter(e=>!term||(`${e.name} ${e.category}`).toLowerCase().includes(term)).slice(0,100).map(e=>`<button type="button" class="list-row" onclick="Calis.pickExercise('${e.id}')"><span><b>${esc(e.name)}</b><small>${esc(e.category)}</small></span><span>›</span></button>`).join('');}
  $('#pickerSearch').addEventListener('input',e=>renderPicker(e.target.value));
  function pickExercise(id){const ex=state.exercises.find(e=>e.id===id);$('#pickerModal').close();state.pickerCallback?.(ex);}
  function openCustomExercise(){openModal('Własne ćwiczenie',async()=>{const name=$('#mExName').value.trim();if(!name)return false;const slug=('custom-'+crypto.randomUUID());const ex=await q(db.from('exercises').insert({slug,name,category:$('#mExCat').value.trim()||'Własne',equipment:$('#mExEquip').value.trim(),tracking_type:$('#mExTrack').value,owner_id:state.user.id,is_public:false}).select().single());state.exercises.push(ex);renderExerciseLibrary();return true;},`<label>Nazwa<input id="mExName"></label><label>Kategoria<input id="mExCat" placeholder="np. Plecy"></label><label>Sprzęt<input id="mExEquip"></label><label>Śledzenie<select id="mExTrack"><option value="weight_reps">kg + powt.</option><option value="bodyweight_reps">masa ciała + powt.</option><option value="duration">czas</option><option value="distance">dystans</option><option value="reps">powtórzenia</option></select></label>`);}

  // NUTRITION
  $('#nutritionDate').value=todayISO(); $('#nutritionDate').addEventListener('change',loadNutrition); $('#calculateCalories').addEventListener('click',calculateCalories); $('#foodSearch').addEventListener('input',searchFoods); $('#newFoodBtn').addEventListener('click',openFoodModal);
  async function loadNutrition(){
    const date=$('#nutritionDate').value||todayISO();
    const logs=await q(db.from('meal_logs').select('*,foods(*)').eq('user_id',state.user.id).eq('eaten_on',date).order('created_at'),true)||[];
    let kcal=0,p=0,c=0,f=0; logs.forEach(l=>{const m=l.grams/100;kcal+=l.foods.kcal_100g*m;p+=l.foods.protein_100g*m;c+=l.foods.carbs_100g*m;f+=l.foods.fat_100g*m;});
    $('#kcalNow').textContent=Math.round(kcal);$('#proteinNow').textContent=Math.round(p);$('#carbsNow').textContent=Math.round(c);$('#fatNow').textContent=Math.round(f);
    $('#kcalTarget').textContent=state.settings.kcal_target||'—';$('#proteinTarget').textContent=state.settings.protein_target||'—';$('#carbsTarget').textContent=state.settings.carbs_target||'—';$('#fatTarget').textContent=state.settings.fat_target||'—';
    $('#mealLog').innerHTML=logs.length?logs.map(l=>`<div class="list-row"><div><b>${esc(l.foods.name)}</b><small>${l.grams} g • ${Math.round(l.foods.kcal_100g*l.grams/100)} kcal • B ${fmt(l.foods.protein_100g*l.grams/100)} / W ${fmt(l.foods.carbs_100g*l.grams/100)} / T ${fmt(l.foods.fat_100g*l.grams/100)}</small></div><button onclick="Calis.deleteMeal('${l.id}')">✕</button></div>`).join(''):'<p class="muted">Brak wpisów.</p>';
    const last=await q(db.from('measurements').select('weight_kg').eq('user_id',state.user.id).order('measured_on',{ascending:false}).limit(1),true); $('#calcWeight').value=last?.[0]?.weight_kg||state.settings.target_weight_kg||'';$('#calcHeight').value=state.settings.height_cm||'';$('#calcBirth').value=state.settings.birth_year||'';$('#calcSex').value=state.settings.sex||'male';$('#calcActivity').value=state.settings.activity_factor||1.45;$('#calcGoal').value=state.settings.goal||'maintain';
  }
  async function calculateCalories(){
    const w=+$('#calcWeight').value,h=+$('#calcHeight').value,b=+$('#calcBirth').value,sex=$('#calcSex').value,af=+$('#calcActivity').value,goal=$('#calcGoal').value;if(!w||!h||!b){toast('Uzupełnij wagę, wzrost i rok urodzenia');return;}
    const age=new Date().getFullYear()-b;const bmr=10*w+6.25*h-5*age+(sex==='male'?5:-161);const tdee=Math.round(bmr*af);const target=Math.round(tdee+(goal==='gain'?200:goal==='cut'?-350:0));const protein=Math.round(w*(goal==='cut'?2.0:1.8));const fat=Math.round(w*0.9);const carbs=Math.max(0,Math.round((target-protein*4-fat*9)/4));
    await q(db.from('user_settings').update({birth_year:b,sex,height_cm:h,activity_factor:af,goal,kcal_target:target,protein_target:protein,fat_target:fat,carbs_target:carbs,updated_at:new Date().toISOString()}).eq('user_id',state.user.id)); state.settings={...state.settings,birth_year:b,sex,height_cm:h,activity_factor:af,goal,kcal_target:target,protein_target:protein,fat_target:fat,carbs_target:carbs};
    $('#calorieResult').classList.remove('hidden');$('#calorieResult').innerHTML=`BMR <b>${Math.round(bmr)} kcal</b> • utrzymanie ~<b>${tdee} kcal</b><br>Cel: <b>${target} kcal</b> • B ${protein} g / W ${carbs} g / T ${fat} g`;loadNutrition();
  }
  async function searchFoods(){const term=$('#foodSearch').value.trim();if(term.length<2){$('#foodResults').innerHTML='';return;}const foods=await q(db.from('foods').select('*').ilike('name',`%${term}%`).limit(30),true)||[];$('#foodResults').innerHTML=foods.map(f=>`<div class="list-row"><div><b>${esc(f.name)}</b><small>${f.kcal_100g} kcal/100 g • B ${f.protein_100g} / W ${f.carbs_100g} / T ${f.fat_100g}</small></div><button onclick="Calis.addFood('${f.id}','${esc(f.name)}')">+</button></div>`).join('')||'<p class="muted">Brak. Dodaj własny produkt.</p>';}
  function addFood(id,name){openModal('Dodaj do dziennika',async()=>{const grams=+$('#mFoodGrams').value;if(!grams)return false;await q(db.from('meal_logs').insert({user_id:state.user.id,food_id:id,eaten_on:$('#nutritionDate').value||todayISO(),meal_type:$('#mMealType').value,grams}));await loadNutrition();return true;},`<p><b>${name}</b></p><label>Gramy<input id="mFoodGrams" type="number" value="100"></label><label>Posiłek<select id="mMealType"><option value="lunch">Obiad</option><option value="breakfast">Śniadanie</option><option value="dinner">Kolacja</option><option value="snack">Przekąska</option><option value="other">Inne</option></select></label>`);}
  async function deleteMeal(id){await q(db.from('meal_logs').delete().eq('id',id));loadNutrition();}
  function openFoodModal(){openModal('Własny produkt',async()=>{const name=$('#mFoodName').value.trim();if(!name)return false;await q(db.from('foods').insert({owner_id:state.user.id,name,brand:$('#mFoodBrand').value.trim(),kcal_100g:+$('#mKcal').value||0,protein_100g:+$('#mProtein').value||0,carbs_100g:+$('#mCarbs').value||0,fat_100g:+$('#mFat').value||0,is_public:false}));toast('Produkt dodany');return true;},`<label>Nazwa<input id="mFoodName"></label><label>Marka<input id="mFoodBrand"></label><div class="form-grid"><label>kcal/100g<input id="mKcal" type="number"></label><label>Białko<input id="mProtein" type="number" step="0.1"></label><label>Węgle<input id="mCarbs" type="number" step="0.1"></label><label>Tłuszcz<input id="mFat" type="number" step="0.1"></label></div>`);}

  // SUPPLEMENTS
  $('#newSupplementBtn').addEventListener('click',openSupplementModal);
  async function getTodaySupplementRows(){
    const dow=mondayIndex(new Date());
    const [schedules,logs,trainingEvents]=await Promise.all([
      q(db.from('supplement_schedules').select('*,supplements(*)').eq('user_id',state.user.id).eq('enabled',true).contains('weekdays',[dow]),true),
      q(db.from('supplement_logs').select('schedule_id').eq('user_id',state.user.id).eq('taken_on',todayISO()),true),
      q(db.from('calendar_events').select('id').eq('user_id',state.user.id).eq('event_date',todayISO()).eq('kind','training'),true)
    ]);
    const isTrainingDay=(trainingEvents||[]).length>0;
    const filtered=(schedules||[]).filter(x=>x.relation_to_workout==='any'||(isTrainingDay&&['training_only','before_training','after_training'].includes(x.relation_to_workout))||(!isTrainingDay&&x.relation_to_workout==='rest_only'));
    const taken=new Set((logs||[]).map(x=>x.schedule_id));return filtered.map(x=>({...x,taken:taken.has(x.id)}));
  }
  async function loadSupplements(){
    const [supps,today]=await Promise.all([q(db.from('supplements').select('*,supplement_schedules(*)').eq('user_id',state.user.id).order('created_at'),true),getTodaySupplementRows()]);
    $('#todaySupplements').innerHTML=today.length?today.map(s=>`<div class="list-row"><div><b>${esc(s.supplements.name)}</b><small>${s.supplements.dose??''} ${esc(s.supplements.unit)} ${s.time_of_day?'• '+s.time_of_day.slice(0,5):''}</small></div><button class="check-btn ${s.taken?'done':''}" onclick="Calis.toggleSupplement('${s.id}',${s.taken})">${s.taken?'✓':'Weź'}</button></div>`).join(''):'<p class="muted">Brak suplementów na dziś.</p>';
    $('#supplementList').innerHTML=(supps||[]).map(s=>`<div class="supp-card"><div class="supp-head"><div><b>${esc(s.name)}</b><small>${s.dose??''} ${esc(s.unit)} • ${s.supplement_schedules?.[0]?.time_of_day?.slice(0,5)||'bez godziny'}</small></div><button class="danger ghost" onclick="Calis.deleteSupplement('${s.id}')">✕</button></div><p class="muted">${esc(s.instructions||'')}</p></div>`).join('');
  }
  function openSupplementModal(){openModal('Dodaj suplement',async()=>{const name=$('#mSuppName').value.trim();if(!name)return false;const s=await q(db.from('supplements').insert({user_id:state.user.id,name,dose:$('#mSuppDose').value?+$('#mSuppDose').value:null,unit:$('#mSuppUnit').value,instructions:$('#mSuppInstructions').value.trim()}).select().single());const days=$$('.m-day:checked').map(x=>+x.value);await q(db.from('supplement_schedules').insert({supplement_id:s.id,user_id:state.user.id,weekdays:days.length?days:[1,2,3,4,5,6,7],time_of_day:$('#mSuppTime').value||null,relation_to_workout:$('#mSuppRelation').value}));await loadSupplements();return true;},`<label>Nazwa<input id="mSuppName" placeholder="np. kreatyna"></label><div class="form-grid"><label>Dawka<input id="mSuppDose" type="number" step="0.1"></label><label>Jednostka<select id="mSuppUnit"><option>g</option><option>mg</option><option>kaps.</option><option>tabl.</option><option>ml</option></select></label><label>Godzina<input id="mSuppTime" type="time"></label><label>Powiązanie z treningiem<select id="mSuppRelation"><option value="any">Każdy dzień</option><option value="training_only">Tylko treningowy</option><option value="rest_only">Tylko bez treningu</option><option value="before_training">Przed treningiem</option><option value="after_training">Po treningu</option></select></label></div><label>Dni</label><div class="chips">${[['1','Pn'],['2','Wt'],['3','Śr'],['4','Cz'],['5','Pt'],['6','Sb'],['7','Nd']].map(([v,n])=>`<label class="chip"><input class="m-day" type="checkbox" value="${v}" checked> ${n}</label>`).join('')}</div><label>Notatka<input id="mSuppInstructions" placeholder="np. do posiłku"></label>`);}
  async function toggleSupplement(scheduleId,taken){if(taken)await q(db.from('supplement_logs').delete().eq('schedule_id',scheduleId).eq('taken_on',todayISO()));else await q(db.from('supplement_logs').insert({schedule_id:scheduleId,user_id:state.user.id,taken_on:todayISO()}));loadSupplements();loadHome();}
  async function deleteSupplement(id){if(confirm('Usunąć suplement i harmonogram?')){await q(db.from('supplements').delete().eq('id',id));loadSupplements();}}

  // CALENDAR
  $('#calendarMonth').value=todayISO().slice(0,7);$('#calendarMonth').addEventListener('change',loadCalendar);$('#newEventBtn').addEventListener('click',openEventModal);
  async function loadCalendar(){
    const month=$('#calendarMonth').value||todayISO().slice(0,7);const [y,m]=month.split('-').map(Number);const start=`${month}-01`;const end=new Date(y,m,0).toISOString().slice(0,10);const ev=await q(db.from('calendar_events').select('*,plans(name)').eq('user_id',state.user.id).gte('event_date',start).lte('event_date',end).order('event_date').order('event_time'),true)||[];
    const first=new Date(y,m-1,1),days=new Date(y,m,0).getDate(),offset=mondayIndex(first)-1;let cells=Array.from({length:offset},()=>'<div></div>');for(let d=1;d<=days;d++){const iso=`${month}-${String(d).padStart(2,'0')}`,has=ev.some(x=>x.event_date===iso);cells.push(`<button class="calendar-cell ${iso===todayISO()?'today':''} ${has?'has-event':''}" onclick="Calis.calendarDay('${iso}')">${d}</button>`);}$('#calendarGrid').innerHTML=cells.join('');renderCalendarEvents(ev);
  }
  function renderCalendarEvents(ev){$('#calendarEvents').innerHTML=ev.length?ev.map(e=>`<div class="card"><div class="row"><div><b>${e.kind==='training'?'🏋️':'📅'} ${esc(e.title)}</b><small class="muted">${e.event_date}${e.event_time?' • '+e.event_time.slice(0,5):''}${e.plans?.name?' • '+esc(e.plans.name):''}</small></div><button class="danger ghost" onclick="Calis.deleteEvent('${e.id}')">✕</button></div></div>`).join(''):'<div class="empty"><p>Brak wpisów w tym miesiącu.</p></div>';}
  function calendarDay(date){openEventModal(date);}
  function openEventModal(date=todayISO()){openModal('Wpis do kalendarza',async()=>{const repeats=Math.max(1,Math.min(52,+$('#mRepeatWeeks').value||1));const base=new Date($('#mEventDate').value+'T12:00:00');const rows=[];for(let i=0;i<repeats;i++){const d=new Date(base);d.setDate(d.getDate()+i*7);rows.push({user_id:state.user.id,event_date:d.toISOString().slice(0,10),event_time:$('#mEventTime').value||null,kind:$('#mEventKind').value,title:$('#mEventTitle').value.trim()||'Wpis',plan_id:$('#mEventPlan').value||null,notes:$('#mEventNotes').value.trim()});}await q(db.from('calendar_events').insert(rows));await loadCalendar();await loadHome();return true;},`<label>Data<input id="mEventDate" type="date" value="${date}"></label><label>Godzina<input id="mEventTime" type="time"></label><label>Typ<select id="mEventKind"><option value="training">Trening</option><option value="measurement">Pomiar</option><option value="recovery">Regeneracja</option><option value="note">Notatka</option></select></label><label>Tytuł<input id="mEventTitle" placeholder="np. Trening A"></label><label>Plan<select id="mEventPlan"><option value="">—</option>${state.plans.map(p=>`<option value="${p.id}">${esc(p.name)}</option>`).join('')}</select></label><label>Powtarzaj co tydzień przez<input id="mRepeatWeeks" type="number" min="1" max="52" value="1"></label><label>Notatka<input id="mEventNotes"></label>`);}
  async function deleteEvent(id){await q(db.from('calendar_events').delete().eq('id',id));loadCalendar();loadHome();}

  // RANKING
  $$('[data-rank]').forEach(b=>b.addEventListener('click',()=>{$$('[data-rank]').forEach(x=>x.classList.toggle('active',x===b));state.rankMode=b.dataset.rank;renderLeaderboard();}));
  async function loadLeaderboard(homeOnly=false){
    const rows=await q(db.rpc('get_global_leaderboard',{p_limit:100}),true)||[];state.leaderboard=rows.map(r=>({...r,profiles:{display_name:r.display_name,username:r.username}}));if(homeOnly){const keep=state.rankMode;state.rankMode='score';$('#homeLeaderboard').innerHTML=state.leaderboard.slice(0,5).map((r,i)=>rankRow(r,i)).join('')||'<p class="muted">Ranking jest pusty.</p>';state.rankMode=keep;return;}renderLeaderboard();
  }
  function rankVal(r){return state.rankMode==='season'?r.season_xp:state.rankMode==='xp'?r.lifetime_xp:state.rankMode==='streak'?r.current_streak:r.calis_score;}
  function renderLeaderboard(){const sorted=[...state.leaderboard].sort((a,b)=>rankVal(b)-rankVal(a));const top=sorted.slice(0,3);$('#leaderboardPodium').innerHTML=top.length?`<div class="podium">${[1,0,2].map((idx,pos)=>{const r=top[idx];if(!r)return'<div></div>';return `<div class="podium-card ${idx===0?'first':''}"><div>${idx===0?'🥇':idx===1?'🥈':'🥉'}</div><b>${esc(r.profiles.display_name)}</b><small>${fmt(rankVal(r))}</small></div>`}).join('')}</div>`:'';$('#leaderboardList').innerHTML=sorted.map((r,i)=>rankRow(r,i)).join('')||'<p class="muted">Brak użytkowników.</p>';}
  function rankRow(r,i){return `<div class="rank-row ${r.user_id===state.user.id?'me':''}"><span class="rank-num">${i+1}</span><div><b>${esc(r.profiles.display_name)}</b><small>@${esc(r.profiles.username||'user')} • ${r.workout_count} treningów • 🔥 ${r.current_streak}</small></div><b>${fmt(rankVal(r))}</b></div>`;}

  // PROGRESS
  $('#newMeasurementBtn').addEventListener('click',openMeasurementModal);
  async function loadProgress(){
    const [meas,userSkills,workouts] = await Promise.all([
      q(db.from('measurements').select('*').eq('user_id',state.user.id).order('measured_on',{ascending:false}).limit(20),true),
      q(db.from('user_skills').select('*,skill_definitions(*)').eq('user_id',state.user.id),true),
      q(db.from('workouts').select('id,started_at,workout_sets(*,exercises(name))').eq('user_id',state.user.id).not('finished_at','is',null).order('started_at',{ascending:false}).limit(50),true)
    ]);
    $('#measurementsList').innerHTML=(meas||[]).map(m=>`<div class="list-row"><div><b>${m.measured_on} • ${m.weight_kg??'—'} kg</b><small>${m.waist_cm?'pas '+m.waist_cm+' cm ':''}${m.chest_cm?'• klatka '+m.chest_cm+' cm':''}</small></div></div>`).join('')||'<p class="muted">Brak pomiarów.</p>';
    const skillMap=new Map((userSkills||[]).map(x=>[x.skill_id,x])); $('#skillsList').innerHTML=state.skills.map(s=>{const u=skillMap.get(s.id),lv=u?.level||0;return `<div class="skill-row" onclick="Calis.editSkill('${s.id}')"><div class="row"><b>${esc(s.name)}</b><span class="tag">LV ${lv}/${s.max_level}</span></div><div class="skill-bar"><i style="width:${lv/s.max_level*100}%"></i></div></div>`}).join('');
    const prs=new Map();for(const w of workouts||[])for(const s of w.workout_sets||[]){const key=s.exercise_id;const score=num(s.weight_kg)*(1+num(s.reps)/30);const bodyScore=num(s.reps)*100+num(s.weight_kg);const val=num(s.weight_kg)>0?score:bodyScore;if(!prs.has(key)||prs.get(key).val<val)prs.set(key,{val,text:num(s.weight_kg)>0?`${s.weight_kg} kg × ${s.reps||0}`:`${s.reps||0} powt.`,name:s.exercises?.name});}$('#prsList').innerHTML=[...prs.values()].slice(0,30).map(p=>`<div class="list-row"><div><b>${esc(p.name)}</b><small>${p.text}</small></div><span>🏆</span></div>`).join('')||'<p class="muted">Brak rekordów.</p>';
  }
  function openMeasurementModal(){openModal('Nowy pomiar',async()=>{await q(db.from('measurements').insert({user_id:state.user.id,measured_on:$('#mMeasureDate').value,weight_kg:$('#mWeight').value?+$('#mWeight').value:null,waist_cm:$('#mWaist').value?+$('#mWaist').value:null,chest_cm:$('#mChest').value?+$('#mChest').value:null,arm_cm:$('#mArm').value?+$('#mArm').value:null,bodyfat_pct:$('#mBodyfat').value?+$('#mBodyfat').value:null}));await loadProgress();return true;},`<label>Data<input id="mMeasureDate" type="date" value="${todayISO()}"></label><div class="form-grid"><label>Waga kg<input id="mWeight" type="number" step="0.1"></label><label>Pas cm<input id="mWaist" type="number" step="0.1"></label><label>Klatka cm<input id="mChest" type="number" step="0.1"></label><label>Ramię cm<input id="mArm" type="number" step="0.1"></label><label>BF %<input id="mBodyfat" type="number" step="0.1"></label></div>`);}
  function editSkill(id){const s=state.skills.find(x=>x.id===id);openModal(s.name,async()=>{const level=+$('#mSkillLevel').value;await q(db.from('user_skills').upsert({user_id:state.user.id,skill_id:id,level,updated_at:new Date().toISOString()},{onConflict:'user_id,skill_id'}));await loadProgress();await loadHome();return true;},`<label>Poziom<select id="mSkillLevel">${Array.from({length:s.max_level+1},(_,i)=>`<option value="${i}">${i}/${s.max_level}${i?` — ${esc(s.steps?.[i-1]||'')}`:''}</option>`).join('')}</select></label>`);}

  // PROFILE
  function renderProfile(){if(!state.profile)return;$('#profileDisplayName').value=state.profile.display_name||'';$('#profileUsername').value=state.profile.username||'';$('#profileHeight').value=state.settings.height_cm||'';$('#profileWeeklyGoal').value=state.settings.weekly_goal||2;$('#profileTargetWeight').value=state.settings.target_weight_kg||'';$('#profilePublic').value=String(state.profile.is_public);}
  $('#saveProfileBtn').addEventListener('click',async()=>{try{const p=await q(db.from('profiles').update({display_name:$('#profileDisplayName').value.trim(),username:$('#profileUsername').value.trim(),is_public:$('#profilePublic').value==='true'}).eq('id',state.user.id).select().single());await q(db.from('user_settings').update({height_cm:$('#profileHeight').value?+$('#profileHeight').value:null,weekly_goal:+$('#profileWeeklyGoal').value||2,target_weight_kg:$('#profileTargetWeight').value?+$('#profileTargetWeight').value:null,updated_at:new Date().toISOString()}).eq('user_id',state.user.id));state.profile=p;state.settings={...state.settings,height_cm:+$('#profileHeight').value||null,weekly_goal:+$('#profileWeeklyGoal').value||2,target_weight_kg:+$('#profileTargetWeight').value||null};$('#profileName').textContent=p.display_name;$('#profileInitial').textContent=p.display_name[0]?.toUpperCase();toast('Profil zapisany');loadHome();}catch{}});

  // MODAL
  function openModal(title,onSave,body){$('#modalTitle').textContent=title;$('#modalBody').innerHTML=body;$('#modalForm').onsubmit=async e=>{if(e.submitter?.value==='cancel')return;e.preventDefault();try{const ok=await onSave();if(ok!==false)$('#modal').close();}catch{}};$('#modal').showModal();}

  // REST TIMER
  function startRest(sec){state.restSeconds=sec;clearInterval(state.restTimer);$('#restTimer').classList.remove('hidden');renderRest();state.restTimer=setInterval(()=>{state.restSeconds--;renderRest();if(state.restSeconds<=0){stopRest();if(navigator.vibrate)navigator.vibrate([120,60,120]);}},1000);}
  function renderRest(){const s=Math.max(0,state.restSeconds);$('#restValue').textContent=String(Math.floor(s/60)).padStart(2,'0')+':'+String(s%60).padStart(2,'0');}
  function stopRest(){clearInterval(state.restTimer);$('#restTimer').classList.add('hidden');}
  $('#restMinus').onclick=()=>{state.restSeconds=Math.max(0,state.restSeconds-15);renderRest();};$('#restPlus').onclick=()=>{state.restSeconds+=15;renderRest();};$('#restClose').onclick=stopRest;

  // Global functions for inline event handlers
  window.Calis={startPlan,editPlan:id=>openPlanEditor(state.plans.find(p=>p.id===id)),deletePlan,removePlanItem:i=>{state.selectedPlanExercises.splice(i,1);renderPlanModalItems();},planField:(i,k,v)=>state.selectedPlanExercises[i][k]=v,setVal,doneSet,addSet,startRest,setExerciseCategory,pickExercise,addFood,deleteMeal,toggleSupplement,deleteSupplement,calendarDay,deleteEvent,editSkill};

  // Initial auth session
  db.auth.getSession().then(({data})=>setSession(data.session));
})();
if('serviceWorker' in navigator){window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(console.error));}
