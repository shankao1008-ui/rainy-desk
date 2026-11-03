const en=document.documentElement.lang.startsWith('en');
const messages=en?{idle:'Choose a sound to preview. This website does not monitor your keyboard.',stopped:'Preview stopped.',playing:'Previewing: ',finished:'Preview complete. Adjust sound and volume in the Mac app.',error:'Could not play this sound. Please try again.'}:{idle:'點選音色試聽，網站不會讀取你的鍵盤。',stopped:'已停止試聽。',playing:'正在試聽：',finished:'試聽完畢。下載 App 後可調整音量與音色。',error:'音效暫時無法播放，請再點一次試聽。'};
const buttons=[...document.querySelectorAll('[data-sound]')];
const status=document.getElementById('audio-status');
let audio=null;
let selected=null;
let generation=0;
function stop(){generation++;if(audio){audio.pause();audio.currentTime=0;}audio=null;selected=null;buttons.forEach(b=>{b.setAttribute('aria-pressed','false');b.querySelector('.play').textContent='▷';});}
buttons.forEach(button=>button.addEventListener('click',async()=>{
 const was=selected===button;stop();if(was){status.textContent=messages.stopped;return;}
 selected=button;const token=generation;
 audio=new Audio(`/audio/${button.dataset.sound}.wav`);audio.volume=.65;
 button.setAttribute('aria-pressed','true');button.querySelector('.play').textContent='Ⅱ';
 status.textContent=messages.playing+button.querySelector('strong').textContent;
 audio.addEventListener('ended',()=>{if(token===generation){stop();status.textContent=messages.finished;}});
 try{await audio.play();}catch{if(token===generation){stop();status.textContent=messages.error;}}
}));
document.addEventListener('visibilitychange',()=>{if(document.hidden){stop();status.textContent=messages.idle;}});
