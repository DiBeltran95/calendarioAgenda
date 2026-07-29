<script lang="ts">
  import { onMount } from 'svelte';

  let container: HTMLDivElement;
  let sketchInstance: any = null;

  function loadScript(src: string): Promise<void> {
    return new Promise((resolve) => {
      const existing = document.querySelector(`script[src="${src}"]`);
      if (existing) { resolve(); return; }
      const s = document.createElement('script');
      s.src = src;
      s.onload = () => resolve();
      document.head.appendChild(s);
    });
  }

  function initSketch() {
    if (!container || !(window as any).p5 || !(window as any).gsap) return;

    const p5Ctor = (window as any).p5;

    const sketch = (p: any) => {
      const particles: any[] = [];
      const amount = 800;
      const durationShrink = 8;
      const durationGrow = 8;
      const total = durationShrink + durationGrow;
      const theme = ['#22c55e', '#3b82f6', '#10b981', '#60a5fa', '#a7f3d0'];

      const proxy = { progress: 1, val: 0 };
      let progress: any;
      let interpolator: any;

      class Particle {
        i: number; cos: number; sin: number; r: number; offset: number; color: string;
        constructor(i: number) {
          this.i = i;
          this.cos = p.cos(i * p.TWO_PI);
          this.sin = p.sin(i * p.TWO_PI);
          this.r = p.floor(p.random(1, 4));
          this.offset = p.pow(p.random(1, 2), 2.5) * p.random(-0.015, 0.015);
          this.color = p.random(theme);
        }
        draw() {
          interpolator.progress((proxy.progress + this.i) % 1);
          const r = p.width * (0.35 + proxy.val * this.offset);
          const x = this.cos * r + p.width / 2;
          const y = this.sin * r + p.width / 2;
          p.fill(this.color);
          p.circle(x, y, this.r);
        }
      }

      const isMobile = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

      p.setup = () => {
        const size = container.offsetWidth || 180;
        const canvas = p.createCanvas(size, size);
        canvas.parent(container);
        p.noStroke();

        const gsap = (window as any).gsap;
        progress = gsap.to(proxy, {
          progress: 0, ease: 'none', duration: total, repeat: -1,
        });

        interpolator = gsap
          .timeline({ paused: true, reverse: true })
          .to(proxy, { val: 1, duration: durationShrink, ease: 'elastic.in(1.5, 0.15)' })
          .to(proxy, { val: 0, duration: durationGrow, ease: 'back.in(3)' });

        // En móvil: anima val automáticamente sin esperar interacción
        if (isMobile) {
          gsap.to(proxy, {
            val: 1, duration: durationShrink, ease: 'elastic.in(1.5, 0.15)',
            yoyo: true, repeat: -1,
          });
        }

        for (let i = 0; i < amount; i++) {
          particles.push(new Particle(i / amount));
        }
      };

      // Solo en escritorio responde al mouse
      p.mouseMoved = () => {
        if (isMobile) return;
        let angle = p.atan2(p.mouseY - p.height / 2, p.mouseX - p.width / 2);
        angle = angle < 0 ? angle + p.TWO_PI : angle;
        angle = p.abs(angle / p.TWO_PI) * total;
        progress.time(angle);
      };

      // Touch deshabilitado completamente
      p.touchMoved = () => false;

      p.draw = () => {
        p.clear();
        particles.forEach((pt) => pt.draw());
      };
    };

    sketchInstance = new p5Ctor(sketch);
  }

  onMount(() => {
    (async () => {
      await loadScript('https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.7.0/p5.min.js');
      await loadScript('https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.2/gsap.min.js');
      initSketch();
    })();

    return () => {
      if (sketchInstance) sketchInstance.remove();
    };
  });
</script>

<div bind:this={container} class="particle-wrap"></div>

<style>
  .particle-wrap {
    width: 100%;
    height: 100%;
  }
  .particle-wrap :global(canvas) {
    display: block;
    margin: auto;
    touch-action: none;
    filter: drop-shadow(0px 0px 5px rgba(34, 197, 94, 0.55))
            drop-shadow(0px 0px 12px rgba(59, 130, 246, 0.35));
  }
</style>
