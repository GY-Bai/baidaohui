<script>
  import { createEventDispatcher, onMount, onDestroy } from 'svelte';
  import Button from './Button.svelte';
  
  export let isOpen = false;
  export let maxDuration = 60; // 最大录音时长（秒）
  export let minDuration = 1; // 最小录音时长（秒）
  export let showWaveform = true;
  export let autoClose = true;
  
  const dispatch = createEventDispatcher();
  
  let isRecording = false;
  let isPaused = false;
  let isPlaying = false;
  let recordingTime = 0;
  let playbackTime = 0;
  let audioBlob = null;
  let audioUrl = null;
  let mediaRecorder = null;
  let audioChunks = [];
  let recordingInterval = null;
  let playbackInterval = null;
  let audioElement = null;
  let waveformData = [];
  let analyserNode = null;
  let audioContext = null;
  
  $: formattedRecordingTime = formatTime(recordingTime);
  $: formattedPlaybackTime = formatTime(playbackTime);
  $: canSend = audioBlob && recordingTime >= minDuration;
  $: isOverTime = recordingTime >= maxDuration;
  
  function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }
  
  async function startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });
      
      // 创建音频上下文用于波形显示
      if (showWaveform) {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const source = audioContext.createMediaStreamSource(stream);
        analyserNode = audioContext.createAnalyser();
        analyserNode.fftSize = 256;
        source.connect(analyserNode);
        
        // 开始更新波形数据
        updateWaveform();
      }
      
      mediaRecorder = new MediaRecorder(stream, {
        mimeType: MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : 'audio/mp4'
      });
      
      audioChunks = [];
      
      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunks.push(event.data);
        }
      };
      
      mediaRecorder.onstop = () => {
        audioBlob = new Blob(audioChunks, { type: mediaRecorder.mimeType });
        audioUrl = URL.createObjectURL(audioBlob);
        
        // 停止音频流
        stream.getTracks().forEach(track => track.stop());
        
        // 清理音频上下文
        if (audioContext) {
          audioContext.close();
          audioContext = null;
        }
      };
      
      mediaRecorder.start();
      isRecording = true;
      recordingTime = 0;
      
      // 开始计时
      recordingInterval = setInterval(() => {
        recordingTime++;
        
        // 自动停止录音如果超过最大时长
        if (recordingTime >= maxDuration) {
          stopRecording();
        }
      }, 1000);
      
      dispatch('start');
      
    } catch (error) {
      console.error('录音启动失败:', error);
      dispatch('error', { message: '无法访问麦克风，请检查权限设置' });
    }
  }
  
  function stopRecording() {
    if (mediaRecorder && isRecording) {
      mediaRecorder.stop();
      isRecording = false;
      
      if (recordingInterval) {
        clearInterval(recordingInterval);
        recordingInterval = null;
      }
      
      dispatch('stop', { duration: recordingTime });
    }
  }
  
  function pauseRecording() {
    if (mediaRecorder && isRecording) {
      mediaRecorder.pause();
      isPaused = true;
      
      if (recordingInterval) {
        clearInterval(recordingInterval);
        recordingInterval = null;
      }
      
      dispatch('pause');
    }
  }
  
  function resumeRecording() {
    if (mediaRecorder && isPaused) {
      mediaRecorder.resume();
      isPaused = false;
      
      // 继续计时
      recordingInterval = setInterval(() => {
        recordingTime++;
        
        if (recordingTime >= maxDuration) {
          stopRecording();
        }
      }, 1000);
      
      dispatch('resume');
    }
  }
  
  function playRecording() {
    if (!audioUrl) return;
    
    if (audioElement) {
      audioElement.pause();
      audioElement.currentTime = 0;
    }
    
    audioElement = new Audio(audioUrl);
    audioElement.currentTime = 0;
    
    audioElement.onplay = () => {
      isPlaying = true;
      playbackTime = 0;
      
      playbackInterval = setInterval(() => {
        playbackTime = Math.floor(audioElement.currentTime);
      }, 100);
      
      dispatch('playStart');
    };
    
    audioElement.onpause = () => {
      isPlaying = false;
      if (playbackInterval) {
        clearInterval(playbackInterval);
        playbackInterval = null;
      }
      dispatch('playPause');
    };
    
    audioElement.onended = () => {
      isPlaying = false;
      playbackTime = 0;
      if (playbackInterval) {
        clearInterval(playbackInterval);
        playbackInterval = null;
      }
      dispatch('playEnd');
    };
    
    audioElement.play();
  }
  
  function pausePlayback() {
    if (audioElement && isPlaying) {
      audioElement.pause();
    }
  }
  
  function updateWaveform() {
    if (!analyserNode) return;
    
    const bufferLength = analyserNode.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    
    const updateData = () => {
      if (!isRecording || !analyserNode) return;
      
      analyserNode.getByteFrequencyData(dataArray);
      
      // 简化波形数据
      const samples = 32;
      const step = Math.floor(bufferLength / samples);
      const newWaveformData = [];
      
      for (let i = 0; i < samples; i++) {
        const index = i * step;
        const value = dataArray[index] / 255;
        newWaveformData.push(value);
      }
      
      waveformData = newWaveformData;
      
      requestAnimationFrame(updateData);
    };
    
    updateData();
  }
  
  function handleSend() {
    if (!canSend) return;
    
    dispatch('send', {
      audioBlob,
      audioUrl,
      duration: recordingTime,
      mimeType: mediaRecorder?.mimeType || 'audio/webm'
    });
    
    if (autoClose) {
      handleClose();
    }
  }
  
  function handleDelete() {
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl);
    }
    
    audioBlob = null;
    audioUrl = null;
    recordingTime = 0;
    playbackTime = 0;
    waveformData = [];
    
    if (audioElement) {
      audioElement.pause();
      audioElement = null;
    }
    
    dispatch('delete');
  }
  
  function handleClose() {
    // 清理录音状态
    if (isRecording) {
      stopRecording();
    }
    
    if (isPlaying) {
      pausePlayback();
    }
    
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl);
    }
    
    // 重置状态
    isRecording = false;
    isPaused = false;
    isPlaying = false;
    recordingTime = 0;
    playbackTime = 0;
    audioBlob = null;
    audioUrl = null;
    waveformData = [];
    
    if (recordingInterval) {
      clearInterval(recordingInterval);
      recordingInterval = null;
    }
    
    if (playbackInterval) {
      clearInterval(playbackInterval);
      playbackInterval = null;
    }
    
    if (audioElement) {
      audioElement.pause();
      audioElement = null;
    }
    
    if (audioContext) {
      audioContext.close();
      audioContext = null;
    }
    
    dispatch('close');
  }
  
  onDestroy(() => {
    handleClose();
  });
</script>

{#if isOpen}
  <div class="voice-recorder">
    <!-- 头部 -->
    <header class="recorder-header">
      <h3 class="recorder-title">语音录制</h3>
      <button class="close-btn" on:click={handleClose}>
        ✕
      </button>
    </header>
    
    <!-- 录音状态显示 -->
    <div class="recording-display">
      {#if isRecording || isPaused}
        <!-- 录音中 -->
        <div class="recording-active">
          <div class="recording-animation" class:paused={isPaused}>
            <div class="recording-dot"></div>
            <div class="recording-ripple"></div>
          </div>
          
          <div class="recording-info">
            <div class="recording-status">
              {#if isPaused}
                <span class="status-text">录音已暂停</span>
              {:else}
                <span class="status-text">正在录音...</span>
              {/if}
            </div>
            <div class="recording-time">
              {formattedRecordingTime}
              {#if maxDuration > 0}
                <span class="time-limit">/ {formatTime(maxDuration)}</span>
              {/if}
            </div>
          </div>
          
          <!-- 波形显示 -->
          {#if showWaveform && !isPaused}
            <div class="waveform-display">
              {#each waveformData as amplitude, index}
                <div 
                  class="waveform-bar"
                  style="height: {Math.max(2, amplitude * 30)}px;"
                ></div>
              {/each}
            </div>
          {/if}
        </div>
        
        <!-- 录音控制按钮 */
        <div class="recording-controls">
          {#if isPaused}
            <Button variant="primary" on:click={resumeRecording}>
              继续录音
            </Button>
          {:else}
            <Button variant="outline" on:click={pauseRecording}>
              暂停
            </Button>
          {/if}
          
          <Button variant="danger" on:click={stopRecording}>
            停止录音
          </Button>
        </div>
        
      {:else if audioBlob}
        <!-- 录音完成 -->
        <div class="recording-complete">
          <div class="playback-display">
            <div class="playback-icon" class:playing={isPlaying}>
              {#if isPlaying}
                ⏸️
              {:else}
                ▶️
              {/if}
            </div>
            
            <div class="playback-info">
              <div class="playback-duration">
                时长: {formattedRecordingTime}
              </div>
              <div class="playback-time">
                {#if isPlaying}
                  {formattedPlaybackTime} / {formattedRecordingTime}
                {:else}
                  点击播放试听
                {/if}
              </div>
            </div>
          </div>
          
          <!-- 简单的播放进度条 -->
          <div class="playback-progress">
            <div 
              class="progress-bar"
              style="width: {recordingTime > 0 ? (playbackTime / recordingTime) * 100 : 0}%"
            ></div>
          </div>
        </div>
        
        <!-- 播放控制按钮 -->
        <div class="playback-controls">
          {#if isPlaying}
            <Button variant="outline" on:click={pausePlayback}>
              暂停播放
            </Button>
          {:else}
            <Button variant="outline" on:click={playRecording}>
              播放试听
            </Button>
          {/if}
          
          <Button variant="outline" on:click={handleDelete}>
            重新录制
          </Button>
        </div>
        
      {:else}
        <!-- 初始状态 -->
        <div class="recording-idle">
          <div class="idle-icon">🎤</div>
          <div class="idle-text">点击下方按钮开始录音</div>
          <div class="idle-hint">
            {#if minDuration > 0}
              最短录音时间: {minDuration}秒
            {/if}
            {#if maxDuration > 0}
              最长录音时间: {maxDuration}秒
            {/if}
          </div>
        </div>
      {/if}
    </div>
    
    <!-- 主要操作按钮 -->
    <div class="main-actions">
      {#if !isRecording && !audioBlob}
        <Button 
          variant="primary" 
          size="lg" 
          fullWidth
          on:click={startRecording}
        >
          开始录音
        </Button>
      {:else if audioBlob}
        <div class="final-actions">
          <Button variant="outline" on:click={handleDelete}>
            删除
          </Button>
          <Button 
            variant="primary" 
            disabled={!canSend}
            on:click={handleSend}
          >
            {#if recordingTime < minDuration}
              录音太短
            {:else}
              发送语音
            {/if}
          </Button>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .voice-recorder {
    background: white;
    border-radius: 20px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
    border: 1px solid #e5e7eb;
    width: 100%;
    max-width: 360px;
    overflow: hidden;
    animation: recorderSlideIn 0.3s ease-out;
  }
  
  @keyframes recorderSlideIn {
    from {
      opacity: 0;
      transform: translateY(20px) scale(0.95);
    }
    to {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }
  
  /* 头部 */
  .recorder-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .recorder-title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0;
  }
  
  .close-btn {
    background: none;
    border: none;
    font-size: 16px;
    color: #6b7280;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    transition: all 0.2s ease;
  }
  
  .close-btn:hover {
    color: #111827;
    background: #f3f4f6;
  }
  
  /* 录音显示区域 */
  .recording-display {
    padding: 32px 20px;
    text-align: center;
  }
  
  /* 录音中状态 */
  .recording-active {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 20px;
  }
  
  .recording-animation {
    position: relative;
    width: 80px;
    height: 80px;
  }
  
  .recording-dot {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 24px;
    height: 24px;
    background: #ef4444;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    animation: recordingPulse 1.5s ease-in-out infinite;
  }
  
  .recording-ripple {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 80px;
    height: 80px;
    border: 2px solid #ef4444;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    animation: recordingRipple 1.5s ease-out infinite;
  }
  
  .recording-animation.paused .recording-dot {
    background: #f59e0b;
    animation-play-state: paused;
  }
  
  .recording-animation.paused .recording-ripple {
    border-color: #f59e0b;
    animation-play-state: paused;
  }
  
  @keyframes recordingPulse {
    0%, 100% { transform: translate(-50%, -50%) scale(1); }
    50% { transform: translate(-50%, -50%) scale(1.2); }
  }
  
  @keyframes recordingRipple {
    0% {
      opacity: 1;
      transform: translate(-50%, -50%) scale(0.3);
    }
    100% {
      opacity: 0;
      transform: translate(-50%, -50%) scale(1.2);
    }
  }
  
  .recording-info {
    text-align: center;
  }
  
  .status-text {
    display: block;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 8px;
  }
  
  .recording-time {
    font-size: 20px;
    font-weight: 700;
    color: #ef4444;
    font-family: monospace;
  }
  
  .time-limit {
    font-size: 14px;
    color: #6b7280;
    font-weight: 400;
  }
  
  /* 波形显示 */
  .waveform-display {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 2px;
    height: 40px;
    margin-top: 16px;
  }
  
  .waveform-bar {
    width: 3px;
    background: #ef4444;
    border-radius: 2px;
    transition: height 0.1s ease;
    min-height: 2px;
  }
  
  /* 录音完成状态 */
  .recording-complete {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
  }
  
  .playback-display {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  
  .playback-icon {
    width: 60px;
    height: 60px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .playback-icon:hover {
    transform: scale(1.05);
  }
  
  .playback-icon.playing {
    animation: playingPulse 2s ease-in-out infinite;
  }
  
  @keyframes playingPulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
  }
  
  .playback-info {
    text-align: left;
  }
  
  .playback-duration {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 4px;
  }
  
  .playback-time {
    font-size: 14px;
    color: #6b7280;
    font-family: monospace;
  }
  
  .playback-progress {
    width: 100%;
    height: 4px;
    background: #e5e7eb;
    border-radius: 2px;
    overflow: hidden;
  }
  
  .progress-bar {
    height: 100%;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    transition: width 0.1s ease;
  }
  
  /* 初始状态 */
  .recording-idle {
    text-align: center;
  }
  
  .idle-icon {
    font-size: 48px;
    margin-bottom: 16px;
    opacity: 0.7;
  }
  
  .idle-text {
    font-size: 16px;
    color: #111827;
    font-weight: 500;
    margin-bottom: 8px;
  }
  
  .idle-hint {
    font-size: 13px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 控制按钮 */
  .recording-controls,
  .playback-controls {
    display: flex;
    gap: 12px;
    justify-content: center;
    margin-top: 16px;
  }
  
  .main-actions {
    padding: 20px;
    border-top: 1px solid #f3f4f6;
  }
  
  .final-actions {
    display: flex;
    gap: 12px;
  }
  
  .final-actions > :global(button) {
    flex: 1;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .voice-recorder {
      max-width: 100%;
      border-radius: 16px;
    }
    
    .recorder-header {
      padding: 12px 16px;
    }
    
    .recorder-title {
      font-size: 14px;
    }
    
    .recording-display {
      padding: 24px 16px;
    }
    
    .recording-animation {
      width: 70px;
      height: 70px;
    }
    
    .recording-ripple {
      width: 70px;
      height: 70px;
    }
    
    .recording-dot {
      width: 20px;
      height: 20px;
    }
    
    .playback-icon {
      width: 50px;
      height: 50px;
      font-size: 20px;
    }
    
    .idle-icon {
      font-size: 40px;
    }
    
    .idle-text {
      font-size: 14px;
    }
    
    .main-actions {
      padding: 16px;
    }
    
    .recording-controls,
    .playback-controls {
      flex-direction: column;
      gap: 8px;
    }
    
    .final-actions {
      flex-direction: column;
      gap: 8px;
    }
  }
</style> 