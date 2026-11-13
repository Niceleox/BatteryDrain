(() => {
  const canvas = document.getElementById("field");
  const gl = canvas.getContext("webgl2", {
    antialias: false,
    alpha: false,
    powerPreference: "high-performance"
  }) || canvas.getContext("webgl", {
    antialias: false,
    alpha: false,
    powerPreference: "high-performance"
  });

  const runtimeEl = document.getElementById("runtime");
  const statusEl = document.getElementById("status");
  const fpsEl = document.getElementById("fps");
  const cpuEl = document.getElementById("cpu");
  const wakeEl = document.getElementById("wake");
  const toggle = document.getElementById("toggle");
  const toggleIcon = document.getElementById("toggleIcon");
  const toggleText = document.getElementById("toggleText");
  const boost = document.getElementById("boost");

  const state = {
    running: false,
    boosted: false,
    startedAt: 0,
    elapsedBeforePause: 0,
    rafId: 0,
    frameCount: 0,
    fpsStartedAt: 0,
    workers: [],
    wakeLock: null,
    particleCount: 26000
  };

  if (!gl) {
    statusEl.textContent = "WebGL unavailable";
    toggle.disabled = true;
    return;
  }

  const program = createProgram(gl, vertexSource(), fragmentSource());
  const timeLocation = gl.getUniformLocation(program, "u_time");
  const resolutionLocation = gl.getUniformLocation(program, "u_resolution");
  const particleIdLocation = gl.getAttribLocation(program, "a_particleId");
  const particleIds = gl.createBuffer();
  const particleIdData = new Float32Array(state.particleCount);

  for (let index = 0; index < particleIdData.length; index += 1) {
    particleIdData[index] = index;
  }

  gl.bindBuffer(gl.ARRAY_BUFFER, particleIds);
  gl.bufferData(gl.ARRAY_BUFFER, particleIdData, gl.STATIC_DRAW);

  gl.useProgram(program);
  gl.clearColor(0.015, 0.02, 0.026, 1);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE);

  function resize() {
    const scale = Math.min(window.devicePixelRatio || 1, 3);
    const width = Math.max(1, Math.floor(window.innerWidth * scale));
    const height = Math.max(1, Math.floor(window.innerHeight * scale));

    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
      gl.viewport(0, 0, width, height);
    }
  }

  function draw(now) {
    if (!state.running) return;

    resize();
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(program);
    gl.bindBuffer(gl.ARRAY_BUFFER, particleIds);
    gl.enableVertexAttribArray(particleIdLocation);
    gl.vertexAttribPointer(particleIdLocation, 1, gl.FLOAT, false, 0, 0);
    gl.uniform1f(timeLocation, (now - state.startedAt) / 1000);
    gl.uniform2f(resolutionLocation, canvas.width, canvas.height);
    gl.drawArrays(gl.POINTS, 0, state.particleCount);

    state.frameCount += 1;
    if (!state.fpsStartedAt) state.fpsStartedAt = now;
    if (now - state.fpsStartedAt >= 1000) {
      const fps = Math.round((state.frameCount * 1000) / (now - state.fpsStartedAt));
      fpsEl.textContent = `${fps} fps`;
      state.frameCount = 0;
      state.fpsStartedAt = now;
    }

    updateRuntime();
    state.rafId = requestAnimationFrame(draw);
  }

  async function start() {
    if (state.running) return;

    state.running = true;
    state.startedAt = performance.now() - state.elapsedBeforePause;
    state.frameCount = 0;
    state.fpsStartedAt = 0;
    statusEl.textContent = "Running WebGL + CPU work";
    toggle.classList.add("running");
    toggleIcon.textContent = "■";
    toggleText.textContent = "Stop";

    startWorkers();
    await requestWakeLock();
    state.rafId = requestAnimationFrame(draw);
  }

  function stop(reason = "Stopped") {
    if (!state.running) return;

    state.running = false;
    state.elapsedBeforePause = performance.now() - state.startedAt;
    cancelAnimationFrame(state.rafId);
    stopWorkers();
    releaseWakeLock();
    statusEl.textContent = reason;
    fpsEl.textContent = "120 target";
    toggle.classList.remove("running");
    toggleIcon.textContent = "▶";
    toggleText.textContent = "Start";
    updateRuntime();
  }

  function startWorkers() {
    stopWorkers();
    const workerCount = state.boosted ? 5 : 3;
    const workerUrl = URL.createObjectURL(new Blob([workerSource()], { type: "text/javascript" }));

    for (let index = 0; index < workerCount; index += 1) {
      const worker = new Worker(workerUrl);
      worker.postMessage({ type: "start", boosted: state.boosted });
      state.workers.push(worker);
    }

    URL.revokeObjectURL(workerUrl);
    cpuEl.textContent = `${workerCount} workers`;
  }

  function stopWorkers() {
    for (const worker of state.workers) {
      worker.postMessage({ type: "stop" });
      worker.terminate();
    }
    state.workers = [];
    cpuEl.textContent = state.boosted ? "5 workers" : "3 workers";
  }

  async function requestWakeLock() {
    if (!("wakeLock" in navigator)) {
      wakeEl.textContent = "manual";
      return;
    }

    try {
      state.wakeLock = await navigator.wakeLock.request("screen");
      wakeEl.textContent = "on";
      state.wakeLock.addEventListener("release", () => {
        if (state.running) wakeEl.textContent = "manual";
      });
    } catch {
      wakeEl.textContent = "manual";
    }
  }

  function releaseWakeLock() {
    if (state.wakeLock) {
      state.wakeLock.release().catch(() => {});
      state.wakeLock = null;
    }
    wakeEl.textContent = "idle";
  }

  function updateRuntime() {
    const elapsed = state.running
      ? performance.now() - state.startedAt
      : state.elapsedBeforePause;
    const totalSeconds = Math.floor(elapsed / 1000);
    const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, "0");
    const seconds = String(totalSeconds % 60).padStart(2, "0");
    runtimeEl.textContent = `${minutes}:${seconds}`;
  }

  function createProgram(glContext, vertex, fragment) {
    const vertexShader = compileShader(glContext, glContext.VERTEX_SHADER, vertex);
    const fragmentShader = compileShader(glContext, glContext.FRAGMENT_SHADER, fragment);
    const linkedProgram = glContext.createProgram();

    glContext.attachShader(linkedProgram, vertexShader);
    glContext.attachShader(linkedProgram, fragmentShader);
    glContext.linkProgram(linkedProgram);

    if (!glContext.getProgramParameter(linkedProgram, glContext.LINK_STATUS)) {
      throw new Error(glContext.getProgramInfoLog(linkedProgram) || "WebGL link failed");
    }

    return linkedProgram;
  }

  function compileShader(glContext, type, source) {
    const shader = glContext.createShader(type);
    glContext.shaderSource(shader, source);
    glContext.compileShader(shader);

    if (!glContext.getShaderParameter(shader, glContext.COMPILE_STATUS)) {
      throw new Error(glContext.getShaderInfoLog(shader) || "WebGL compile failed");
    }

    return shader;
  }

  function vertexSource() {
    return `
      precision highp float;

      attribute float a_particleId;
      uniform float u_time;
      uniform vec2 u_resolution;

      float hash(float n) {
        return fract(sin(n) * 43758.5453123);
      }

      void main() {
        float id = a_particleId;
        float seedA = hash(id * 12.9898);
        float seedB = hash(id * 78.233);
        float seedC = hash(id * 37.719);
        float radius = 0.08 + seedA * 0.92;
        float angle = seedB * 6.2831853 + u_time * (0.26 + seedC * 1.42);
        float wave = sin(u_time * 2.15 + id * 0.021) * 0.08;
        vec2 position = vec2(cos(angle), sin(angle)) * (radius + wave);

        position.x += sin(u_time * 0.84 + id * 0.031) * 0.17;
        position.y += cos(u_time * 0.67 + id * 0.029) * 0.13;
        position.x *= u_resolution.y / u_resolution.x;

        gl_Position = vec4(position, 0.0, 1.0);
        gl_PointSize = 1.25 + seedC * 2.75;
      }
    `;
  }

  function fragmentSource() {
    return `
      precision highp float;

      void main() {
        vec2 point = gl_PointCoord - vec2(0.5);
        float alpha = smoothstep(0.5, 0.06, length(point));
        vec3 color = mix(vec3(0.28, 0.9, 0.62), vec3(0.38, 0.78, 1.0), gl_PointCoord.x);
        gl_FragColor = vec4(color, alpha * 0.72);
      }
    `;
  }

  function workerSource() {
    return `
      let active = false;
      let boosted = false;
      let sink = 0.731;

      self.onmessage = (event) => {
        if (event.data.type === "start") {
          active = true;
          boosted = Boolean(event.data.boosted);
          run();
        }
        if (event.data.type === "stop") {
          active = false;
        }
      };

      function run() {
        if (!active) return;
        const rounds = boosted ? 140000 : 90000;

        for (let i = 0; i < rounds; i += 1) {
          const input = i + sink;
          sink = Math.sin(input) + Math.cos(sink + Math.sqrt(Math.abs(input))) * Math.atan(input % 97);
        }

        setTimeout(run, boosted ? 0 : 8);
      }
    `;
  }

  toggle.addEventListener("click", () => {
    if (state.running) {
      stop("Stopped");
    } else {
      start();
    }
  });

  boost.addEventListener("click", () => {
    state.boosted = !state.boosted;
    boost.setAttribute("aria-pressed", String(state.boosted));
    if (state.running) startWorkers();
    cpuEl.textContent = state.boosted ? "5 workers" : "3 workers";
  });

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      stop("Paused");
    } else if (state.running && !state.wakeLock) {
      requestWakeLock();
    }
  });

  window.addEventListener("resize", resize);
  resize();
})();
