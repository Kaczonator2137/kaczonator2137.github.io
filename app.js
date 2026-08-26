const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];

const EXERCISES = [
 {id:"pullup",name:"Podciąganie nachwytem",cat:"Plecy",type:"bodyweight",rest:120},
 {id:"chinup",name:"Podciąganie podchwytem / neutral",cat:"Plecy",type:"bodyweight",rest:120},
 {id:"dips",name:"Dipy na poręczach",cat:"Klatka / triceps",type:"bodyweight",rest:120},
 {id:"pushup",name:"Pompki",cat:"Klatka",type:"bodyweight",rest:90},
 {id:"ohp",name:"Wyciskanie hantli nad głowę",cat:"Barki",type:"weight",rest:120},
 {id:"squat",name:"Przysiad / Hack squat",cat:"Nogi",type:"weight",rest:150},
 {id:"rdl",name:"RDL",cat:"Tył uda / pośladki",type:"weight",rest:150},
 {id:"row",name:"Wiosłowanie",cat:"Plecy",type:"weight",rest:120},
 {id:"latpull",name:"Ściąganie drążka",cat:"Plecy",type:"weight",rest:100},
 {id:"lateral",name:"Unoszenie hantli bokiem",cat:"Barki",type:"weight",rest:60},
 {id:"facepull",name:"Face pull",cat:"Tył barków",type:"weight",rest:60},
 {id:"legraise",name:"Unoszenie nóg w zwisie",cat:"Core",type:"bodyweight",rest:75},
 {id:"abwheel",name:"Ab wheel",cat:"Core",type:"bodyweight",rest:90},
 {id:"farmer",name:"Farmer walk",cat:"Chwyt / core",type:"time",rest:90},
 {id:"curl",name:"Uginanie hantli",cat:"Biceps",type:"weight",rest:75},
 {id:"triceps",name:"Prostowanie tricepsa na wyciągu",cat:"Triceps",type:"weight",rest:75},
 {id:"bench",name:"Wyciskanie na ławce",cat:"Klatka",type:"weight",rest:120},
 {id:"bulgarian",name:"Bułgarski przysiad",cat:"Nogi",type:"weight",rest:90},
 {id:"calf",name:"Wspięcia na palce",cat:"Łydki",type:"weight",rest:60},
 {id:"plank",name:"Plank",cat:"Core",type:"time",rest:60},
 {id:"pike",name:"Pike push-up",cat:"Barki",type:"bodyweight",rest:90}
];

const DEFAULT_PLANS = [
 {id:"A",name:"Trening A",desc:"Pull + Push + Legs",exercises:[
  {exerciseId:"pullup",sets:4,range:"4–8"},
  {exerciseId:"dips",sets:4,range:"5–10"},
  {exerciseId:"squat",sets:3,range:"6–10"},
  {exerciseId:"row",sets:3,range:"8–12"},
  {exerciseId:"lateral",sets:3,range:"12–20"},
  {exerciseId:"legraise",sets:3,range:"8–15"},
  {exerciseId:"facepull",sets:2,range:"15–20"}
 ]},
 {id:"B",name:"Trening B",desc:"Shoulders + Pull + Posterior",exercises:[
  {exerciseId:"chinup",sets:4,range:"5–10"},
  {exerciseId:"ohp",sets:3,range:"6–10"},
  {exerciseId:"rdl",sets:3,range:"6–10"},
  {exerciseId:"pushup",sets:3,range:"8–15"},
  {exerciseId:"latpull",sets:3,range:"8–12"},
  {exerciseId:"lateral",sets:3,range:"12–20"},
  {exerciseId:"abwheel",sets:3,range:"6–12"},
  {exerciseId:"farmer",sets:2,range:"30–60 s"}
 ]}
];

const SKILLS = [
 {id:"pullup",name:"Podciąganie",icon:"🧗",steps:["1 czyste","5 czystych","8 czystych","12 czystych","+20 kg × 3"]},
 {id:"dips",name:"Dipy",icon:"⚡",steps:["1 czysty","5 czystych","10 czystych","15 czystych","+30 kg × 3"]},
 {id:"lsit",name:"L-sit",icon:"◼︎",steps:["Tuck hold","10 sekund","20 sekund","30 sekund","45 sekund"]},
 {id:"handstand",name:"Handstand",icon:"🤸",steps:["Przy ścianie","5 sekund","15 sekund","30 sekund","60 sekund"]},
 {id:"muscleup",name:"Muscle-up",icon:"🚀",steps:["Negatyw","Z gumą","1 powtórzenie","3 powtórzenia","5 powtórzeń"]},
 {id:"frontlever",name:"Front lever",icon:"🪽",steps:["Tuck","Advanced tuck","One leg","Straddle","Full lever"]}
];

const ACHIEVEMENTS = [
 {id:"first",name:"Pierwsza krew",desc:"Ukończ pierwszy trening",icon:"🏁",check:s=>s.workouts.length>=1},
 {id:"ten",name:"Wchodzi w nawyk",desc:"Ukończ 10 treningów",icon:"🔟",check:s=>s.workouts.length>=10},
 {id:"fifty",name:"Maszyna",desc:"Ukończ 50 treningów",icon:"🏆",check:s=>s.workouts.length>=50},
 {id:"streak4",name:"Regularność",desc:"4 tygodnie z aktywnością",icon:"🔥",check:s=>calcStreak(s)>=4},
 {id:"pr5",name:"Rekordzista",desc:"Ustaw 5 rekordów",icon:"🥇",check:s=>Object.keys(s.prs).length>=5},
 {id:"skill1",name:"Skill unlocked",desc:"Ukończ dowolne drzewko skilla",icon:"💎",check:s=>Object.values(s.skills).some(v=>v>=5)},
 {id:"level10",name:"Dwucyfrowy",desc:"Osiągnij 10 poziom",icon:"🔱",check:s=>levelInfo(s.xp).level>=10},
 {id:"volume10k",name:"10 ton",desc:"Przerzuć łącznie 10 000 kg",icon:"🏋️",check:s=>totalVolume(s)>=10000}
];

const initialState = () => ({
 version:2,
 xp:0,
 plans:JSON.parse(JSON.stringify(DEFAULT_PLANS)),
 workouts:[],
 measurements:[{date:new Date().toISOString(),weight:64,waist:null,chest:null,arm:null}],
 skills:Object.fromEntries(SKILLS.map(x=>[x.id,0])),
 prs:{},
 settings:{height:175,startWeight:64,targetWeight:68,weeklyGoal:2},
 lastPlanId:"B",
 activeWorkout:null,
 unlockedAchievements:[]
});

let state = loadState();
let rest = {seconds:0,timer:null};
let sessionTicker = null;
let planEditor = {planId:null,rows:[]};

function loadState(){
 try{
  const raw = JSON.parse(localStorage.getItem("calislevel-pro-state"));
  if(!raw) return initialState();
  const fresh=initialState();
  return {...fresh,...raw,settings:{...fresh.settings,...(raw.settings||{})},skills:{...fresh.skills,...(raw.skills||{})}};
 }catch(e){ return initialState(); }
}
function saveState(){
 checkAchievements();
 localStorage.setItem("calislevel-pro-state",JSON.stringify(state));
 renderAll();
}
function exById(id){return EXERCISES.find(x=>x.id===id) || {id,name:id,cat:"Inne",type:"weight",rest:90}}
function planById(id){return state.plans.find(x=>x.id===id)}
function fmtDate(s){return new Date(s).toLocaleDateString("pl-PL",{day:"2-digit",month:"2-digit",year:"numeric"})}
function fmtTime(s){return new Date(s).toLocaleTimeString("pl-PL",{hour:"2-digit",minute:"2-digit"})}
function clamp(n,a,b){return Math.max(a,Math.min(b,n))}
function uid(prefix="id"){return prefix+"-"+Date.now().toString(36)+"-"+Math.random().toString(36).slice(2,7)}

function levelInfo(xp){
 let level=1, remaining=xp, need=100;
 while(remaining>=need){remaining-=need;level++;need=Math.round(100*Math.pow(1.14,level-1))}
 return {level,remaining,need,pct:remaining/need*100}
}
function rankFor(level){
 const ranks=[
  [1,"Bronze III"],[3,"Bronze II"],[5,"Bronze I"],[7,"Silver III"],[10,"Silver II"],[13,"Silver I"],
  [16,"Gold III"],[20,"Gold II"],[24,"Gold I"],[28,"Platinum"],[34,"Diamond"],[40,"Master"],[50,"Legend"]
 ];
 let out="Bronze III"; ranks.forEach(([l,n])=>{if(level>=l)out=n}); return out;
}
function startOfWeek(d=new Date()){
 const x=new Date(d); const day=(x.getDay()+6)%7; x.setHours(0,0,0,0);x.setDate(x.getDate()-day);return x;
}
function weekWorkoutCount(){
 const start=startOfWeek();
 return state.workouts.filter(w=>new Date(w.date)>=start).length;
}
function calcStreak(s=state){
 if(!s.workouts.length)return 0;
 const weeks=new Set(s.workouts.map(w=>{
  const d=startOfWeek(new Date(w.date));return d.toISOString().slice(0,10)
 }));
 let streak=0; let cursor=startOfWeek();
 for(let i=0;i<60;i++){
  const key=cursor.toISOString().slice(0,10);
  if(weeks.has(key))streak++;
  else if(i===0){} else break;
  cursor.setDate(cursor.getDate()-7);
 }
 return streak;
}
function totalVolume(s=state){return Math.round(s.workouts.reduce((a,w)=>a+(w.volume||0),0))}
function totalSets(){return state.workouts.reduce((a,w)=>a+(w.completedSets||0),0)}
function lastMeasurement(){return state.measurements.at(-1) || null}
function trend(key){
 const arr=state.measurements.filter(x=>x[key]!=null);
 if(arr.length<2)return null;
 return +(arr.at(-1)[key]-arr.at(-2)[key]).toFixed(1);
}

function navigate(screen){
 $$(".screen").forEach(x=>x.classList.toggle("active",x.id==="screen-"+screen));
 $$(".bottom-nav button").forEach(x=>x.classList.toggle("active",x.dataset.nav===screen));
 if(screen==="workout") renderActiveWorkout();
 window.scrollTo({top:0,behavior:"smooth"});
}
$$("[data-nav]").forEach(b=>b.addEventListener("click",()=>navigate(b.dataset.nav)));

function renderAll(){
 renderHome(); renderPlans(); renderActiveWorkout(); renderStats(); renderMeasurements(); renderPRs(); renderSkills(); renderAchievements(); renderLibrary(); syncSettingsInputs();
}
function renderHome(){
 const li=levelInfo(state.xp);
 $("#levelNumber").textContent=li.level;
 $("#rankName").textContent=rankFor(li.level);
 $("#xpTotal").textContent=state.xp+" XP";
 $("#xpToNext").textContent=(li.need-li.remaining)+" XP do kolejnego poziomu";
 $("#xpProgress").style.width=clamp(li.pct,0,100)+"%";
 $("#homeStreak").textContent=calcStreak();
 $("#homeWeek").textContent=weekWorkoutCount()+"/"+state.settings.weeklyGoal;
 $("#homePR").textContent=Object.keys(state.prs).length;
 const lm=lastMeasurement();
 $("#homeWeight").textContent=lm?.weight ? lm.weight.toFixed(1)+" kg":"—";
 $("#homeWaist").textContent=lm?.waist ? lm.waist.toFixed(1)+" cm":"—";
 const wt=trend("weight"), wa=trend("waist");
 $("#weightTrend").textContent=wt==null?"brak trendu":(wt>0?"+":"")+wt+" kg";
 $("#waistTrend").textContent=wa==null?"brak danych":(wa>0?"+":"")+wa+" cm";
 $("#homeVolume").textContent=(state.workouts.at(-1)?.volume||0).toLocaleString("pl-PL")+" kg";
 $("#homeSkills").textContent=Object.values(state.skills).filter(v=>v>=5).length+"/"+SKILLS.length;

 const nextId = state.lastPlanId==="A"?"B":"A";
 const plan=planById(nextId)||state.plans[0];
 $("#nextWorkoutCard").innerHTML = plan ? `
   <div class="plan-card-head"><div><h3>${plan.name}</h3><div class="muted">${plan.desc||""}</div></div><span class="badge">${plan.exercises.length} ćw.</span></div>
   <div class="tag-row">${plan.exercises.slice(0,5).map(e=>`<span class="tag">${exById(e.exerciseId).name}</span>`).join("")}</div>
   <button class="primary-btn full" onclick="startWorkout('${plan.id}')">Rozpocznij trening</button>` : "<p>Dodaj plan treningowy.</p>";

 const missions=[
  {name:"2 treningi w tym tygodniu",now:weekWorkoutCount(),goal:state.settings.weeklyGoal,xp:40},
  {name:"Zapisz pomiar masy",now:state.measurements.filter(m=>new Date(m.date)>=startOfWeek()).length,goal:1,xp:5},
  {name:"Ustaw nowy rekord",now:state.workouts.slice(-2).some(w=>w.prCount>0)?1:0,goal:1,xp:25}
 ];
 $("#missionList").innerHTML=missions.map(m=>`
  <div class="card">
    <div class="plan-card-head"><div><strong>${m.name}</strong><div class="muted" style="font-size:11px">${Math.min(m.now,m.goal)}/${m.goal}</div></div><span class="badge">+${m.xp} XP</span></div>
    <div class="progress"><div style="width:${clamp(m.now/m.goal*100,0,100)}%"></div></div>
  </div>`).join("");
}

function renderPlans(){
 $("#plansList").innerHTML=state.plans.map(p=>`
  <div class="card plan-card">
   <div class="plan-card-head"><div><h3>${p.name}</h3><div class="muted">${p.desc||""}</div></div><span class="badge">${p.exercises.length} ćw.</span></div>
   <div class="tag-row">${p.exercises.slice(0,6).map(e=>`<span class="tag">${exById(e.exerciseId).name} • ${e.sets}×${e.range}</span>`).join("")}</div>
   <div class="plan-actions">
    <button class="primary-btn" onclick="startWorkout('${p.id}')">Start</button>
    <button class="secondary-btn" onclick="openPlanEditor('${p.id}')">Edytuj</button>
    <button class="ghost-btn" onclick="duplicatePlan('${p.id}')">⧉</button>
   </div>
  </div>`).join("");
}
function duplicatePlan(id){
 const p=planById(id); if(!p)return;
 const copy=JSON.parse(JSON.stringify(p)); copy.id=uid("plan"); copy.name=p.name+" kopia"; state.plans.push(copy);saveState();
}
$("#newPlanBtn").addEventListener("click",()=>openPlanEditor(null));
function openPlanEditor(id){
 const p=id?planById(id):{id:null,name:"",desc:"",exercises:[]};
 planEditor.planId=id;
 planEditor.rows=JSON.parse(JSON.stringify(p.exercises));
 $("#planDialogTitle").textContent=id?"Edytuj plan":"Nowy plan";
 $("#planNameInput").value=p.name;$("#planDescInput").value=p.desc||"";
 renderPlanEditorRows();
 $("#planDialog").showModal();
}
function renderPlanEditorRows(){
 $("#planExercisesEditor").innerHTML=planEditor.rows.map((r,i)=>`
  <div class="editor-row">
   <button type="button" class="secondary-btn" style="text-align:left" onclick="pickExercise(${i})">${exById(r.exerciseId).name}</button>
   <input type="number" min="1" max="10" value="${r.sets}" onchange="planEditor.rows[${i}].sets=+this.value">
   <input value="${r.range}" onchange="planEditor.rows[${i}].range=this.value">
   <button type="button" onclick="removePlanRow(${i})">✕</button>
  </div>`).join("");
}
$("#addExerciseToPlanBtn").addEventListener("click",()=>{planEditor.rows.push({exerciseId:"pullup",sets:3,range:"8–12"});renderPlanEditorRows()});
function removePlanRow(i){planEditor.rows.splice(i,1);renderPlanEditorRows()}
function pickExercise(i){
 window._pickerIndex=i; $("#pickerSearch").value=""; renderPicker(""); $("#exercisePickerDialog").showModal();
}
function renderPicker(q){
 q=q.toLowerCase();
 $("#pickerList").innerHTML=EXERCISES.filter(e=>e.name.toLowerCase().includes(q)||e.cat.toLowerCase().includes(q)).map(e=>`
  <button type="button" class="picker-item" onclick="chooseExercise('${e.id}')"><span><strong>${e.name}</strong><small>${e.cat}</small></span><span>›</span></button>`).join("");
}
$("#pickerSearch").addEventListener("input",e=>renderPicker(e.target.value));
function chooseExercise(id){planEditor.rows[window._pickerIndex].exerciseId=id;$("#exercisePickerDialog").close();renderPlanEditorRows()}
$("#planForm").addEventListener("submit",e=>{
 if(e.submitter?.value==="cancel") return;
 e.preventDefault();
 const name=$("#planNameInput").value.trim(); if(!name)return;
 if(planEditor.planId){
  const p=planById(planEditor.planId); p.name=name;p.desc=$("#planDescInput").value.trim();p.exercises=planEditor.rows;
 }else state.plans.push({id:uid("plan"),name,desc:$("#planDescInput").value.trim(),exercises:planEditor.rows});
 $("#planDialog").close();saveState();
});

function startWorkout(planId){
 const plan=planById(planId); if(!plan)return;
 if(state.activeWorkout && !confirm("Masz już aktywny trening. Zastąpić go?")) return;
 state.activeWorkout={
  id:uid("session"),planId,planName:plan.name,start:new Date().toISOString(),
  exercises:plan.exercises.map(p=>({exerciseId:p.exerciseId,range:p.range,sets:Array.from({length:p.sets},()=>({weight:"",reps:"",rpe:"",done:false}))}))
 };
 saveState(); navigate("workout"); startSessionTicker();
}
function startSessionTicker(){
 clearInterval(sessionTicker);
 sessionTicker=setInterval(updateSessionTime,1000);updateSessionTime();
}
function updateSessionTime(){
 const a=state.activeWorkout;if(!a)return;
 const sec=Math.floor((Date.now()-new Date(a.start))/1000);
 $("#sessionTime").textContent=String(Math.floor(sec/60)).padStart(2,"0")+":"+String(sec%60).padStart(2,"0");
}
function renderActiveWorkout(){
 const a=state.activeWorkout;
 $("#activeWorkoutEmpty").classList.toggle("hidden",!!a);
 $("#activeWorkoutContent").classList.toggle("hidden",!a);
 if(!a)return;
 startSessionTicker();
 $("#sessionVolume").textContent=Math.round(activeVolume()).toLocaleString("pl-PL")+" kg";
 $("#activeExerciseList").innerHTML=a.exercises.map((e,ei)=>{
  const ex=exById(e.exerciseId);
  return `<div class="exercise-card">
   <div class="exercise-head">
    <div><h3>${ex.name}</h3><small>${ex.cat} • cel ${e.range}</small></div>
    <button class="ghost-btn" onclick="startRest(${ex.rest})">⏱ ${Math.round(ex.rest/60*10)/10}m</button>
   </div>
   <div class="set-table">
    <div class="set-head"><span>#</span><span>kg/+kg</span><span>powt.</span><span>RPE</span><span>✓</span></div>
    ${e.sets.map((s,si)=>`<div class="set-row">
      <span>${si+1}</span>
      <input inputmode="decimal" type="number" step="0.5" value="${s.weight}" oninput="setValue(${ei},${si},'weight',this.value)">
      <input inputmode="numeric" type="number" value="${s.reps}" oninput="setValue(${ei},${si},'reps',this.value)">
      <input inputmode="decimal" type="number" step="0.5" min="1" max="10" value="${s.rpe}" oninput="setValue(${ei},${si},'rpe',this.value)">
      <input class="set-done" type="checkbox" ${s.done?"checked":""} onchange="toggleSet(${ei},${si},this.checked,${ex.rest})">
     </div>`).join("")}
    <button class="add-set" onclick="addSet(${ei})">+ Dodaj serię</button>
   </div>
  </div>`;
 }).join("");
}
function setValue(ei,si,key,val){state.activeWorkout.exercises[ei].sets[si][key]=val;localStorage.setItem("calislevel-pro-state",JSON.stringify(state));$("#sessionVolume").textContent=Math.round(activeVolume()).toLocaleString("pl-PL")+" kg"}
function toggleSet(ei,si,checked,restSec){
 state.activeWorkout.exercises[ei].sets[si].done=checked;
 localStorage.setItem("calislevel-pro-state",JSON.stringify(state));
 if(checked) startRest(restSec);
}
function addSet(ei){state.activeWorkout.exercises[ei].sets.push({weight:"",reps:"",rpe:"",done:false});saveState()}
function activeVolume(){
 const a=state.activeWorkout;if(!a)return 0;
 return a.exercises.reduce((sum,e)=>sum+e.sets.reduce((s,x)=>s+(x.done?(+x.weight||0)*(+x.reps||0):0),0),0)
}
$("#abandonWorkoutBtn").addEventListener("click",()=>{
 if(!state.activeWorkout)return;
 if(confirm("Usunąć aktywny trening?")){state.activeWorkout=null;saveState();clearInterval(sessionTicker)}
});
$("#finishWorkoutBtn").addEventListener("click",finishWorkout);
function estimate1RM(w,r){if(!w||!r)return 0;return w*(1+r/30)}
function finishWorkout(){
 const a=state.activeWorkout;if(!a)return;
 let completedSets=0,volume=0,prCount=0;
 const details=[];
 a.exercises.forEach(e=>{
  const ex=exById(e.exerciseId);
  const done=e.sets.filter(s=>s.done && +s.reps>0);
  if(!done.length)return;
  completedSets+=done.length;
  volume+=done.reduce((z,s)=>z+(+s.weight||0)*(+s.reps||0),0);
  let best=0,bestText="";
  done.forEach(s=>{
   const w=+s.weight||0,r=+s.reps||0;
   const score=ex.type==="bodyweight" ? r*100 + w : estimate1RM(w,r);
   if(score>best){best=score;bestText=(w?`${w} kg × ${r}`:`${r} powt.`)}
  });
  const old=state.prs[e.exerciseId]?.score||0;
  if(best>old){state.prs[e.exerciseId]={score:best,text:bestText,date:new Date().toISOString(),exercise:ex.name};prCount++}
  details.push({exerciseId:e.exerciseId,sets:done});
 });
 if(!completedSets){alert("Zaznacz przynajmniej jedną ukończoną serię.");return}
 const earned=40+completedSets*10+prCount*25+(weekWorkoutCount()>=state.settings.weeklyGoal-1?20:0);
 state.xp+=earned;
 state.workouts.push({id:a.id,date:new Date().toISOString(),start:a.start,planId:a.planId,planName:a.planName,completedSets,volume:Math.round(volume),prCount,xp:earned,details});
 state.lastPlanId=a.planId;
 state.activeWorkout=null;
 saveState();clearInterval(sessionTicker);stopRest();
 navigate("home");
 alert(`Trening zapisany. +${earned} XP${prCount?` • ${prCount} nowy rekord`:``}`);
}

function startRest(seconds){
 rest.seconds=seconds;clearInterval(rest.timer);$("#restTimer").classList.remove("hidden");renderRest();
 rest.timer=setInterval(()=>{rest.seconds--;renderRest();if(rest.seconds<=0){stopRest();if(navigator.vibrate)navigator.vibrate([150,80,150])}},1000);
}
function renderRest(){const s=Math.max(0,rest.seconds);$("#restTimerValue").textContent=String(Math.floor(s/60)).padStart(2,"0")+":"+String(s%60).padStart(2,"0")}
function stopRest(){clearInterval(rest.timer);rest.timer=null;$("#restTimer").classList.add("hidden")}
$("#restMinus").addEventListener("click",()=>{rest.seconds=Math.max(0,rest.seconds-15);renderRest()});
$("#restPlus").addEventListener("click",()=>{rest.seconds+=15;renderRest()});
$("#restStop").addEventListener("click",stopRest);

$$("[data-progress-tab]").forEach(b=>b.addEventListener("click",()=>{
 $$("[data-progress-tab]").forEach(x=>x.classList.toggle("active",x===b));
 $$(".progress-tab").forEach(x=>x.classList.toggle("active",x.id==="progress-"+b.dataset.progressTab));
 if(b.dataset.progressTab==="photos") renderPhotos();
}));

function lineChart(container,values,labels){
 const el=$(container); if(!values.length){el.innerHTML='<p class="muted">Brak danych.</p>';return}
 const w=320,h=160,p=24; const min=Math.min(...values),max=Math.max(...values); const span=Math.max(1,max-min);
 const pts=values.map((v,i)=>[p+(w-2*p)*(i/Math.max(1,values.length-1)),h-p-(h-2*p)*(v-min)/span]);
 el.innerHTML=`<svg viewBox="0 0 ${w} ${h}">
  ${[0,1,2,3].map(i=>`<line class="gridline" x1="${p}" y1="${p+i*(h-2*p)/3}" x2="${w-p}" y2="${p+i*(h-2*p)/3}"/>`).join("")}
  <polyline class="line" points="${pts.map(x=>x.join(",")).join(" ")}"/>
  ${pts.map((x,i)=>`<circle class="dot" cx="${x[0]}" cy="${x[1]}" r="3.5"/><text x="${x[0]}" y="${h-4}" text-anchor="middle">${labels[i]||""}</text>`).join("")}
 </svg>`;
}
function barChart(container,values,labels){
 const el=$(container); const w=320,h=160,p=24,max=Math.max(1,...values);
 el.innerHTML=`<svg viewBox="0 0 ${w} ${h}">
 ${[0,1,2,3].map(i=>`<line class="gridline" x1="${p}" y1="${p+i*(h-2*p)/3}" x2="${w-p}" y2="${p+i*(h-2*p)/3}"/>`).join("")}
 ${values.map((v,i)=>{const bw=(w-2*p)/values.length*.62;const x=p+(i+.5)*(w-2*p)/values.length-bw/2;const bh=(h-2*p)*v/max;return `<rect class="bar" x="${x}" y="${h-p-bh}" width="${bw}" height="${bh}" rx="4"/><text x="${x+bw/2}" y="${h-5}" text-anchor="middle">${labels[i]}</text>`}).join("")}
 </svg>`;
}
function renderStats(){
 const ms=state.measurements.filter(m=>m.weight).slice(-10);
 lineChart("#weightChart",ms.map(m=>m.weight),ms.map(m=>new Date(m.date).toLocaleDateString("pl-PL",{day:"2-digit",month:"2-digit"})));
 if(ms.length>=2){const d=ms.at(-1).weight-ms[0].weight;$("#weightAvgBadge").textContent=(d>0?"+":"")+d.toFixed(1)+" kg"}else $("#weightAvgBadge").textContent="—";
 const vals=[],labs=[];let cur=startOfWeek();
 for(let i=7;i>=0;i--){const st=new Date(cur);st.setDate(st.getDate()-7*i);const en=new Date(st);en.setDate(en.getDate()+7);vals.push(state.workouts.filter(w=>new Date(w.date)>=st&&new Date(w.date)<en).length);labs.push(st.toLocaleDateString("pl-PL",{day:"2-digit",month:"2-digit"}))}
 barChart("#workoutChart",vals,labs);
 $("#statsWorkouts").textContent=state.workouts.length;$("#statsSets").textContent=totalSets();$("#statsVolume").textContent=totalVolume().toLocaleString("pl-PL")+" kg";$("#statsXP").textContent=state.xp;
}
$("#saveMeasurementBtn").addEventListener("click",()=>{
 const weight=parseFloat($("#bodyWeight").value),waist=parseFloat($("#bodyWaist").value)||null,chest=parseFloat($("#bodyChest").value)||null,arm=parseFloat($("#bodyArm").value)||null;
 if(!weight){alert("Podaj wagę.");return}
 state.measurements.push({date:new Date().toISOString(),weight,waist,chest,arm});state.xp+=5;saveState();
 $("#bodyWaist").value="";$("#bodyChest").value="";$("#bodyArm").value="";
});
function renderMeasurements(){
 $("#measurementHistory").innerHTML=[...state.measurements].reverse().slice(0,30).map(m=>`
  <div class="history-row"><strong>${fmtDate(m.date)} • ${m.weight.toFixed(1)} kg</strong>
  <small>${m.waist?`pas ${m.waist} cm • `:""}${m.chest?`klatka ${m.chest} cm • `:""}${m.arm?`ramię ${m.arm} cm`:""}</small></div>`).join("");
}
function renderPRs(){
 const prs=Object.entries(state.prs).sort((a,b)=>new Date(b[1].date)-new Date(a[1].date));
 $("#prList").innerHTML=prs.length?prs.map(([id,p])=>`<div class="history-row"><strong>${p.exercise||exById(id).name}</strong><small>${p.text} • ${fmtDate(p.date)}</small></div>`).join(""):'<p class="muted">Jeszcze bez rekordów.</p>';
}

function renderSkills(){
 $("#skillList").innerHTML=SKILLS.map(s=>{
  const lv=state.skills[s.id]||0;
  return `<div class="skill-card" onclick="openSkill('${s.id}')">
   <div class="skill-card-head"><div><strong>${s.icon} ${s.name}</strong><div class="muted" style="font-size:11px">${lv<5?s.steps[lv]:"MASTERED"}</div></div><span class="badge">LV ${lv}/5</span></div>
   <div class="skill-bar"><div style="width:${lv*20}%"></div></div>
  </div>`;
 }).join("");
}
function openSkill(id){
 const s=SKILLS.find(x=>x.id===id),lv=state.skills[id]||0;window._skillId=id;
 $("#skillDialogTitle").textContent=s.name;
 $("#skillSteps").innerHTML=s.steps.map((step,i)=>`<button type="button" class="skill-step ${i<lv?"unlocked":""}" onclick="setSkillLevel('${id}',${i+1})"><strong>Poziom ${i+1}</strong><div class="muted">${step}</div></button>`).join("");
 $("#skillDialog").showModal();
}
function setSkillLevel(id,level){
 const old=state.skills[id]||0;if(level>old)state.xp+=(level-old)*20;state.skills[id]=level;$("#skillDialog").close();saveState();
}

function checkAchievements(){
 ACHIEVEMENTS.forEach(a=>{
  if(a.check(state)&&!state.unlockedAchievements.includes(a.id)){state.unlockedAchievements.push(a.id);state.xp+=50}
 });
}
function renderAchievements(){
 $("#achievementList").innerHTML=ACHIEVEMENTS.map(a=>{
  const unlocked=state.unlockedAchievements.includes(a.id);
  return `<div class="achievement ${unlocked?"":"locked"}"><div class="achievement-icon">${a.icon}</div><div><strong>${a.name}</strong><small>${a.desc}</small></div><span>${unlocked?"✓":"🔒"}</span></div>`;
 }).join("");
}
function renderLibrary(filter=""){
 filter=filter.toLowerCase();
 $("#exerciseLibrary").innerHTML=EXERCISES.filter(e=>e.name.toLowerCase().includes(filter)||e.cat.toLowerCase().includes(filter)).map(e=>`<div class="library-item"><span><strong>${e.name}</strong><small>${e.cat} • przerwa ${e.rest}s</small></span><span>›</span></div>`).join("");
}
$("#exerciseSearch").addEventListener("input",e=>renderLibrary(e.target.value));

function syncSettingsInputs(){
 $("#settingsHeight").value=state.settings.height;$("#settingsStartWeight").value=state.settings.startWeight;$("#settingsWeeklyGoal").value=state.settings.weeklyGoal;$("#settingsTargetWeight").value=state.settings.targetWeight;
}
$("#saveSettingsBtn").addEventListener("click",()=>{
 state.settings.height=+$("#settingsHeight").value||175;state.settings.startWeight=+$("#settingsStartWeight").value||64;state.settings.weeklyGoal=clamp(+$("#settingsWeeklyGoal").value||2,1,7);state.settings.targetWeight=+$("#settingsTargetWeight").value||68;saveState();
});

$("#exportBtn").addEventListener("click",()=>{
 const blob=new Blob([JSON.stringify(state,null,2)],{type:"application/json"});const a=document.createElement("a");a.href=URL.createObjectURL(blob);a.download="calislevel-pro-backup.json";a.click();URL.revokeObjectURL(a.href);
});
$("#importInput").addEventListener("change",e=>{
 const f=e.target.files[0];if(!f)return;const r=new FileReader();r.onload=()=>{try{state=JSON.parse(r.result);saveState();alert("Import zakończony.");}catch{alert("Nieprawidłowy plik.")}};r.readAsText(f)
});
$("#resetBtn").addEventListener("click",()=>{if(confirm("Usunąć wszystkie dane aplikacji?")){localStorage.removeItem("calislevel-pro-state");location.reload()}});

const DB_NAME="calislevel-pro-db";
function openDB(){return new Promise((res,rej)=>{const r=indexedDB.open(DB_NAME,1);r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains("photos"))r.result.createObjectStore("photos",{keyPath:"id"})};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)})}
async function addPhoto(file){
 const db=await openDB();const tx=db.transaction("photos","readwrite");tx.objectStore("photos").put({id:uid("photo"),date:new Date().toISOString(),blob:file});return new Promise(r=>tx.oncomplete=r)
}
async function listPhotos(){
 const db=await openDB();const tx=db.transaction("photos","readonly");const req=tx.objectStore("photos").getAll();return new Promise((r,j)=>{req.onsuccess=()=>r(req.result.sort((a,b)=>new Date(b.date)-new Date(a.date)));req.onerror=()=>j(req.error)})
}
async function deletePhoto(id){
 const db=await openDB();const tx=db.transaction("photos","readwrite");tx.objectStore("photos").delete(id);return new Promise(r=>tx.oncomplete=r)
}
$("#photoInput").addEventListener("change",async e=>{const f=e.target.files[0];if(!f)return;await addPhoto(f);e.target.value="";renderPhotos()});
async function renderPhotos(){
 const photos=await listPhotos();$("#photoGrid").innerHTML=photos.length?photos.map(p=>`<div class="photo-card"><img src="${URL.createObjectURL(p.blob)}"><button onclick="removePhoto('${p.id}')">✕</button></div>`).join(""):'<div class="empty-card"><p>Brak zdjęć progresowych.</p></div>'
}
async function removePhoto(id){if(confirm("Usunąć zdjęcie?")){await deletePhoto(id);renderPhotos()}}

$("#profileBtn").addEventListener("click",()=>navigate("more"));

window.startWorkout=startWorkout;window.openPlanEditor=openPlanEditor;window.duplicatePlan=duplicatePlan;window.pickExercise=pickExercise;window.chooseExercise=chooseExercise;window.removePlanRow=removePlanRow;window.setValue=setValue;window.toggleSet=toggleSet;window.addSet=addSet;window.startRest=startRest;window.openSkill=openSkill;window.setSkillLevel=setSkillLevel;window.removePhoto=removePhoto;window.planEditor=planEditor;

if("serviceWorker" in navigator) window.addEventListener("load",()=>navigator.serviceWorker.register("./sw.js").catch(()=>{}));
renderAll();
if(state.activeWorkout) startSessionTicker();
