-- Rozszerzenie biblioteki ćwiczeń CalisLevel.
-- Migracja jest idempotentna: istniejące rekordy i dane użytkowników pozostają bez zmian.

begin;

-- Korekta nazw wygenerowanych wcześniej z błędnym określeniem kończyny.
update public.exercises
set name = replace(replace(replace(name,
  'jednorącz prawa', 'jednonóż — prawa noga'),
  'jednorącz lewa', 'jednonóż — lewa noga'),
  'oburącz', 'obunóż')
where slug like 'leg-extension-%' or slug like 'leg-curl-%';

insert into public.exercises
  (slug,name,category,equipment,movement,difficulty,tracking_type,muscle_primary,muscle_secondary,is_public)
values
-- Biceps
('uginanie-hantle-z-supinacja-naprzemiennie','Uginanie hantli z supinacją — naprzemiennie','Biceps','hantle','elbow flexion','all','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-hantle-z-supinacja-oburacz','Uginanie hantli z supinacją — oburącz','Biceps','hantle','elbow flexion','all','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-hantle-skos-z-supinacja','Uginanie hantli na skosie z supinacją','Biceps','hantle/ławka','elbow flexion','all','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-zottman-hantle','Uginanie Zottmana','Biceps','hantle','elbow flexion','intermediate','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-drag-curl-sztanga','Drag curl ze sztangą','Biceps','sztanga','elbow flexion','all','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-modlitewnik-maszyna','Uginanie na modlitewniku — maszyna','Biceps','maszyna','elbow flexion','all','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-wyciag-jednoracz','Uginanie na wyciągu — jednorącz','Biceps','wyciąg','elbow flexion','all','weight_reps','biceps',array['przedramię']::text[],true),
('uginanie-mlotkowe-lina-wyciag','Uginanie młotkowe z liną na wyciągu','Biceps','wyciąg/lina','elbow flexion','all','weight_reps','biceps',array['ramienny','przedramię']::text[],true),
('uginanie-biceps-21-sztanga-ez','Uginanie 21 ze sztangą EZ','Biceps','sztanga EZ','elbow flexion','intermediate','weight_reps','biceps',array['przedramię']::text[],true),

-- Triceps
('wyciskanie-francuskie-hantel-jednoracz','Wyciskanie francuskie hantlem — jednorącz','Triceps','hantel','elbow extension','all','weight_reps','triceps','{}'::text[],true),
('tate-press-hantle','Tate press','Triceps','hantle/ławka','elbow extension','intermediate','weight_reps','triceps',array['klatka']::text[],true),
('cross-body-triceps-extension-cable','Prostowanie ramienia po skosie na wyciągu','Triceps','wyciąg','elbow extension','all','weight_reps','triceps','{}'::text[],true),
('bodyweight-triceps-extension','Prostowanie tricepsa masą ciała','Triceps','sztanga/drążek','elbow extension','all','bodyweight_reps','triceps',array['core']::text[],true),
('ring-triceps-extension','Prostowanie tricepsa na kółkach','Triceps','kółka','elbow extension','intermediate','bodyweight_reps','triceps',array['core']::text[],true),
('sphinx-push-up','Pompki sfinksa','Triceps','masa ciała','elbow extension','intermediate','bodyweight_reps','triceps',array['barki','core']::text[],true),
('overhead-cable-extension-jednoracz','Prostowanie ramienia nad głową na wyciągu — jednorącz','Triceps','wyciąg','elbow extension','all','weight_reps','triceps','{}'::text[],true),
('pjr-pullover-hantel','PJR pullover','Triceps','hantel/ławka','elbow extension','intermediate','weight_reps','triceps',array['najszerszy']::text[],true),
('rolling-dumbbell-triceps-extension','Rolling dumbbell triceps extension','Triceps','hantle/ławka','elbow extension','intermediate','weight_reps','triceps','{}'::text[],true),

-- Klatka piersiowa
('floor-press-sztanga','Floor press ze sztangą','Klatka','sztanga','horizontal push','all','weight_reps','klatka',array['triceps','barki']::text[],true),
('floor-press-hantle','Floor press z hantlami','Klatka','hantle','horizontal push','all','weight_reps','klatka',array['triceps','barki']::text[],true),
('squeeze-press-hantle','Squeeze press z hantlami','Klatka','hantle/ławka','horizontal push','all','weight_reps','klatka',array['triceps']::text[],true),
('cable-chest-press-stojac','Wyciskanie na bramie stojąc','Klatka','brama','horizontal push','all','weight_reps','klatka',array['triceps','barki','core']::text[],true),
('pompki-deficytowe','Pompki deficytowe','Klatka','uchwyty','horizontal push','intermediate','bodyweight_reps','klatka',array['triceps','barki','core']::text[],true),
('pompki-z-pauza-na-dole','Pompki z pauzą na dole','Klatka','masa ciała','horizontal push','all','bodyweight_reps','klatka',array['triceps','barki','core']::text[],true),
('dipy-z-dodatkowym-ciezarem','Dipy z dodatkowym ciężarem','Klatka','poręcze/pas','vertical push','intermediate','weight_reps','klatka',array['triceps','barki']::text[],true),
('wyciskanie-hantel-jednoracz-lawka-plaska','Wyciskanie hantla jednorącz na ławce płaskiej','Klatka','hantel/ławka','horizontal push','intermediate','weight_reps','klatka',array['triceps','barki','core']::text[],true),

-- Plecy
('inverted-row-sztanga','Wiosłowanie australijskie na sztandze','Plecy','sztanga/masa ciała','row','all','bodyweight_reps','plecy',array['biceps','tył barków','core']::text[],true),
('ring-row','Wiosłowanie na kółkach','Plecy','kółka','row','all','bodyweight_reps','plecy',array['biceps','tył barków','core']::text[],true),
('pendlay-row','Wiosłowanie Pendlay','Plecy','sztanga','row','intermediate','weight_reps','plecy',array['biceps','tył barków','prostowniki']::text[],true),
('meadows-row','Wiosłowanie Meadowsa','Plecy','landmine','row','intermediate','weight_reps','plecy',array['biceps','tył barków']::text[],true),
('wioslowanie-hantle-chest-supported','Wiosłowanie hantlami na ławce skośnej','Plecy','hantle/ławka','row','all','weight_reps','plecy',array['biceps','tył barków']::text[],true),
('high-row-maszyna','High row na maszynie','Plecy','maszyna','row','all','weight_reps','plecy',array['biceps','tył barków']::text[],true),
('kelso-shrug','Szrugsy Kelso','Plecy','sztanga/ławka','scapular retraction','intermediate','weight_reps','kaptury',array['równoległoboczne','tył barków']::text[],true),
('sciaganie-gumy-prostymi-ramionami','Ściąganie gumy prostymi ramionami','Plecy','guma','shoulder extension','all','reps','najszerszy',array['core']::text[],true),
('pullover-hantel-jednoracz','Pullover hantlem — jednorącz','Plecy','hantel/ławka','shoulder extension','all','weight_reps','najszerszy',array['klatka','triceps']::text[],true),
('wioslowanie-kettlebell-gorilla-row','Gorilla row z kettlami','Plecy','kettle','row','intermediate','weight_reps','plecy',array['biceps','core']::text[],true),
('podciaganie-chest-to-bar','Podciąganie chest-to-bar','Plecy','drążek','vertical pull','intermediate','bodyweight_reps','najszerszy',array['biceps','core']::text[],true),
('podciaganie-eksplozywne','Podciąganie eksplozywne','Plecy','drążek','vertical pull','advanced','bodyweight_reps','najszerszy',array['biceps','core']::text[],true),

-- Barki
('upright-row-sztanga','Podciąganie sztangi wzdłuż tułowia','Barki','sztanga','vertical pull','all','weight_reps','barki',array['kaptury','biceps']::text[],true),
('upright-row-wyciag','Podciąganie linki wyciągu wzdłuż tułowia','Barki','wyciąg/lina','vertical pull','all','weight_reps','barki',array['kaptury','biceps']::text[],true),
('lu-raise-hantle','Lu raise','Barki','hantle','shoulder raise','intermediate','weight_reps','barki',array['kaptury']::text[],true),
('cuban-press-hantle','Cuban press','Barki','hantle','shoulder rotation','intermediate','weight_reps','barki',array['stożek rotatorów','kaptury']::text[],true),
('landmine-press-oburacz','Landmine press — oburącz','Barki','landmine','vertical push','all','weight_reps','barki',array['klatka','triceps','core']::text[],true),
('rear-delt-row-hantle','Wiosłowanie na tył barków hantlami','Barki','hantle','row','all','weight_reps','tył barków',array['kaptury','biceps']::text[],true),
('face-pull-z-rotacja-zewnetrzna','Face pull z rotacją zewnętrzną','Barki','wyciąg/lina','rear delt','all','weight_reps','tył barków',array['stożek rotatorów','kaptury']::text[],true),
('handstand-shoulder-shrug','Szrugsy w staniu na rękach','Barki','ściana/masa ciała','scapular elevation','intermediate','bodyweight_reps','barki',array['kaptury','core']::text[],true),

-- Nogi i pośladki
('split-squat-masa-ciala','Split squat — masa ciała','Nogi','masa ciała','squat','all','bodyweight_reps','czworogłowe',array['pośladki','przywodziciele']::text[],true),
('split-squat-hantle','Split squat z hantlami','Nogi','hantle','squat','all','weight_reps','czworogłowe',array['pośladki','przywodziciele']::text[],true),
('bulgarian-split-squat-masa-ciala','Bulgarian split squat — masa ciała','Nogi','ławka/masa ciała','squat','all','bodyweight_reps','czworogłowe',array['pośladki','przywodziciele']::text[],true),
('step-down-jednonoz','Step-down jednonóż','Nogi','podest','squat','all','bodyweight_reps','czworogłowe',array['pośladki']::text[],true),
('lateral-lunge','Wykrok boczny','Nogi','masa ciała','lunge','all','bodyweight_reps','przywodziciele',array['czworogłowe','pośladki']::text[],true),
('spanish-squat','Spanish squat','Czworogłowe','guma','squat','all','reps','czworogłowe',array['pośladki']::text[],true),
('cyclist-squat','Cyclist squat','Czworogłowe','sztanga/podkładka','squat','intermediate','weight_reps','czworogłowe',array['pośladki']::text[],true),
('goblet-squat-piety-uniesione','Goblet squat z uniesionymi piętami','Nogi','hantel/podkładka','squat','all','weight_reps','czworogłowe',array['pośladki','core']::text[],true),
('landmine-squat','Landmine squat','Nogi','landmine','squat','all','weight_reps','czworogłowe',array['pośladki','core']::text[],true),
('safety-bar-squat','Przysiad ze sztangą safety bar','Nogi','safety bar','squat','intermediate','weight_reps','czworogłowe',array['pośladki','prostowniki','core']::text[],true),
('walking-lunge-masa-ciala','Wykroki chodzone — masa ciała','Nogi','masa ciała','lunge','all','bodyweight_reps','czworogłowe',array['pośladki','przywodziciele']::text[],true),
('b-stance-rdl-hantle','B-stance RDL z hantlami','Tył uda','hantle','hinge','intermediate','weight_reps','dwugłowe uda',array['pośladki','prostowniki']::text[],true),
('b-stance-rdl-sztanga','B-stance RDL ze sztangą','Tył uda','sztanga','hinge','intermediate','weight_reps','dwugłowe uda',array['pośladki','prostowniki']::text[],true),
('hip-thrust-jednonoz','Hip thrust jednonóż','Pośladki','ławka/masa ciała','hip extension','all','bodyweight_reps','pośladki',array['dwugłowe uda','core']::text[],true),
('frog-pump','Frog pump','Pośladki','masa ciała','hip extension','all','reps','pośladki',array['przywodziciele']::text[],true),
('back-extension-45-glute','Wyprost tułowia 45° — pośladki','Pośladki','ławka rzymska','hip extension','all','weight_reps','pośladki',array['dwugłowe uda','prostowniki']::text[],true),
('reverse-hyperextension','Reverse hyperextension','Tył uda','maszyna/ławka','hip extension','all','weight_reps','pośladki',array['dwugłowe uda','prostowniki']::text[],true),
('nordic-curl-assisted','Nordic curl z asekuracją','Tył uda','guma/masa ciała','knee flexion','intermediate','bodyweight_reps','dwugłowe uda',array['pośladki','łydki']::text[],true),
('sliding-leg-curl','Sliding leg curl','Tył uda','ślizgacze/masa ciała','knee flexion','all','bodyweight_reps','dwugłowe uda',array['pośladki','łydki']::text[],true),
('hip-thrust-maszyna','Hip thrust na maszynie','Pośladki','maszyna','hip extension','all','weight_reps','pośladki',array['dwugłowe uda']::text[],true),

-- Core
('russian-twist','Russian twist','Core','masa ciała/obciążenie','rotation','all','reps','skośne brzucha',array['prosty brzucha']::text[],true),
('dead-bug-naprzemiennie','Dead bug — naprzemiennie','Core','masa ciała','anti-extension','all','reps','core',array['zginacze bioder']::text[],true),
('bird-dog','Bird dog','Core','masa ciała','anti-rotation','all','reps','core',array['pośladki','prostowniki']::text[],true),
('hanging-windshield-wipers','Hanging windshield wipers','Core','drążek','rotation','advanced','bodyweight_reps','skośne brzucha',array['prosty brzucha','chwyt']::text[],true),
('barbell-rollout','Rollout ze sztangą','Core','sztanga','anti-extension','intermediate','bodyweight_reps','core',array['najszerszy','barki']::text[],true),
('plank-shoulder-tap','Plank shoulder tap','Core','masa ciała','anti-rotation','all','reps','core',array['barki','pośladki']::text[],true),
('hollow-rock','Hollow body rock','Core','masa ciała','anti-extension','intermediate','reps','prosty brzucha',array['zginacze bioder']::text[],true),
('cable-dead-bug','Dead bug z wyciągiem','Core','wyciąg','anti-extension','intermediate','reps','core',array['najszerszy','zginacze bioder']::text[],true),
('decline-sit-up','Brzuszki na ławce ujemnej','Core','ławka','trunk flexion','all','weight_reps','prosty brzucha',array['zginacze bioder']::text[],true),
('copenhagen-hip-adduction','Przywodzenie kopenhaskie','Core','ławka/masa ciała','hip adduction','intermediate','bodyweight_reps','przywodziciele',array['skośne brzucha','pośladki']::text[],true),

-- Kalistenika
('podciaganie-negatywne','Podciąganie negatywne','Kalistenika','drążek','vertical pull','all','bodyweight_reps','najszerszy',array['biceps','core']::text[],true),
('chin-up-negatywny','Podciąganie podchwytem — negatywy','Kalistenika','drążek','vertical pull','all','bodyweight_reps','najszerszy',array['biceps','core']::text[],true),
('muscle-up-z-guma','Muscle-up na drążku z gumą','Kalistenika','drążek/guma','muscle-up','intermediate','bodyweight_reps','plecy',array['biceps','triceps','klatka','core']::text[],true),
('muscle-up-z-wyskoku','Muscle-up z wyskoku','Kalistenika','niski drążek','muscle-up','all','bodyweight_reps','plecy',array['biceps','triceps','klatka','core']::text[],true),
('muscle-up-przejscie-niski-drazek','Przejście muscle-up na niskim drążku','Kalistenika','niski drążek','muscle-up transition','all','reps','triceps',array['plecy','klatka','core']::text[],true),
('scapular-dip','Dipy łopatkowe','Kalistenika','poręcze','scapular depression','all','bodyweight_reps','dolne kaptury',array['triceps','core']::text[],true),
('dipy-negatywne','Dipy negatywne','Kalistenika','poręcze','vertical push','all','bodyweight_reps','triceps',array['klatka','barki']::text[],true),
('korean-dip','Korean dip','Kalistenika','drążek','vertical push','advanced','bodyweight_reps','triceps',array['barki','klatka','core']::text[],true),
('wall-walk','Wall walk','Kalistenika','ściana','vertical push','intermediate','reps','barki',array['triceps','core','klatka']::text[],true),
('handstand-shoulder-tap','Dotknięcia barków w staniu na rękach','Kalistenika','ściana/masa ciała','vertical push','advanced','reps','barki',array['triceps','core']::text[],true),
('front-lever-row-tuck','Front lever row — tuck','Kalistenika','drążek','row','intermediate','bodyweight_reps','plecy',array['biceps','core']::text[],true),
('front-lever-row-advanced-tuck','Front lever row — advanced tuck','Kalistenika','drążek','row','advanced','bodyweight_reps','plecy',array['biceps','core']::text[],true),
('pistol-squat-assisted','Pistol squat z asekuracją','Kalistenika','podpora/masa ciała','squat','all','bodyweight_reps','czworogłowe',array['pośladki','core']::text[],true),
('shrimp-squat-assisted','Shrimp squat z asekuracją','Kalistenika','podpora/masa ciała','squat','all','bodyweight_reps','czworogłowe',array['pośladki','core']::text[],true),
('dragon-squat','Dragon squat','Kalistenika','masa ciała','squat','advanced','bodyweight_reps','czworogłowe',array['pośladki','przywodziciele','core']::text[],true),

-- Mobilność, prehab i szyja
('atg-split-squat','ATG split squat','Mobilność / prehab','masa ciała/obciążenie','lunge','all','weight_reps','czworogłowe',array['zginacze bioder','pośladki']::text[],true),
('terminal-knee-extension-band','Terminal knee extension z gumą','Mobilność / prehab','guma','knee extension','all','reps','czworogłowe','{}'::text[],true),
('shoulder-dislocates-band','Przenoszenie gumy nad głową','Mobilność / prehab','guma','shoulder mobility','all','reps','barki',array['klatka','najszerszy']::text[],true),
('serratus-wall-slide','Wall slide z aktywacją zębatego','Mobilność / prehab','ściana/guma','scapular upward rotation','all','reps','zębaty przedni',array['barki','dolne kaptury']::text[],true),
('hip-cars','Hip CARs','Mobilność / prehab','masa ciała','hip mobility','all','reps','biodra',array['pośladki','zginacze bioder']::text[],true),
('shoulder-cars','Shoulder CARs','Mobilność / prehab','masa ciała','shoulder mobility','all','reps','barki',array['stożek rotatorów']::text[],true),
('wrist-push-up','Pompki na nadgarstki','Mobilność / prehab','masa ciała','wrist strength','intermediate','bodyweight_reps','przedramię',array['triceps']::text[],true),
('neck-flexion-plate','Zginanie szyi z obciążeniem','Szyja','talerz/ławka','neck flexion','all','weight_reps','zginacze szyi','{}'::text[],true),
('neck-extension-plate','Prostowanie szyi z obciążeniem','Szyja','talerz/ławka','neck extension','all','weight_reps','prostowniki szyi','{}'::text[],true),
('neck-lateral-flexion','Zgięcie boczne szyi z obciążeniem','Szyja','talerz/ławka','neck lateral flexion','all','weight_reps','szyja',array['kaptury']::text[],true),
('neck-harness-extension','Prostowanie szyi w uprzęży','Szyja','uprząż','neck extension','intermediate','weight_reps','prostowniki szyi',array['kaptury']::text[],true)
on conflict (slug) do nothing;

commit;
