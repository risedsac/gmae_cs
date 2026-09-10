'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import {
  ArrowUpRight,
  Crosshair,
  Volume2,
  Mouse,
  Shield,
  RotateCcw,
  Play,
  Pause,
  Maximize,
  Target,
} from 'lucide-react';
import { Slider } from '@/components/ui/slider';
import type { DesertGame, GameState } from '@/lib/game';
const initial: GameState = {
  phase: 'menu',
  health: 100,
  armor: 100,
  ammo: 30,
  reserve: 90,
  weapon: 0,
  kills: 0,
  deaths: 0,
  headshots: 0,
  time: 120,
  reloading: false,
  reloadProgress: 0,
  hit: 0,
  hurt: 0,
  spread: 0,
  feed: [],
  fps: 60,
  locked: false,
  dead: false,
  zone: '南部入口',
  shots: 0,
  hits: 0,
};
export default function Home() {
  const canvas = useRef<HTMLCanvasElement>(null),
    radar = useRef<HTMLCanvasElement>(null),
    game = useRef<DesertGame | null>(null);
  const [state, setState] = useState(initial),
    [ready, setReady] = useState(false),
    [error, setError] = useState(''),
    [sensitivity, setSensitivity] = useState(1),
    [volume, setVolume] = useState(65),
    [difficulty, setDifficulty] = useState(1);
  useEffect(() => {
    let cancelled = false;
    import('@/lib/game')
      .then(({ DesertGame }) => {
        if (cancelled || !canvas.current) return;
        try {
          game.current = new DesertGame(
            canvas.current,
            radar.current,
            setState,
          );
          void game.current.assetsReady
            .then(() => {
              if (!cancelled) setReady(true);
            })
            .catch(() => {
              if (!cancelled) setError('装备模型未能加载，请刷新页面重试。');
            });
        } catch (e) {
          setError(
            '画面未能启动，请使用支持 WebGL 的桌面浏览器，并开启硬件加速。',
          );
          console.error(e);
        }
      })
      .catch((e) => {
        setError('游戏加载失败，请刷新页面重试。');
        console.error(e);
      });
    return () => {
      cancelled = true;
      game.current?.dispose();
    };
  }, []);
  useEffect(() => {
    game.current?.configure(sensitivity, volume / 100, difficulty);
  }, [sensitivity, volume, difficulty, ready]);
  const awaitingControls = state.phase === 'ready',
    playing = state.phase === 'playing' || awaitingControls,
    ended = state.phase === 'ended',
    paused = state.phase === 'paused';
  const clockSeconds = Math.ceil(state.time);
  const clockText = `${Math.floor(clockSeconds / 60)}:${String(clockSeconds % 60).padStart(2, '0')}`;
  const full = async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch {
      setError('当前窗口不支持全屏，可在独立浏览器窗口中游玩。');
    }
  };
  return (
    <main className={`game-shell ${playing ? 'in-game' : 'in-menu'}`}>
      <canvas
        className="world"
        ref={canvas}
        aria-label="沙漠据点第一人称游戏画面"
      />
      <div className="scene-shade" />
      <header className="topbar">
        <Link className="wordmark" href="/" aria-label="DUSTLINE 沙境首页">
          <i />
          DUSTLINE<span>沙境</span>
        </Link>
        {!playing && (
          <div className="build-label">
            <i />
            TACTICAL SHOOTER <span>DEMO / 01</span>
          </div>
        )}
        {playing && (
          <div className="match-clock">
            <span>训练</span>
            <b>{clockText}</b>
            <strong>
              {state.kills}
              <small> / 12</small>
            </strong>
          </div>
        )}
        <div className="top-actions">
          <button onClick={full} aria-label="切换全屏">
            <Maximize size={18} />
          </button>
          {playing && (
            <button onClick={() => game.current?.pause()} aria-label="暂停">
              <Pause size={18} />
            </button>
          )}
          <span className="fps">{state.fps} FPS</span>
        </div>
      </header>
      <div className={`radar-wrap ${!playing ? 'menu-radar' : ''}`}>
        <div className="radar-caption">
          <span>{playing ? state.zone : '据点平面图'}</span>
          <span>N ↑</span>
        </div>
        <canvas width="192" height="216" ref={radar} aria-label="地图雷达" />
        <div className="radar-coordinates">
          SECTOR 04 <span>36° N / 04° E</span>
        </div>
      </div>
      {!playing && (
        <>
          <section
            className="briefing"
            aria-label={paused ? '游戏暂停' : '开始训练'}
          >
            <div className="eyebrow">
              <span>01</span>
              <i />
              {ended ? '行动报告' : paused ? '行动暂停' : '行动区域 / 沙漠小镇'}
            </div>
            <h1>
              {ended
                ? state.kills >= 12
                  ? '任务完成'
                  : '训练结束'
                : paused
                  ? '随时归队'
                  : '沙漠据点'}
              <span>
                {ended
                  ? 'AFTER ACTION'
                  : paused
                    ? 'STAND BY'
                    : 'DESERT OUTPOST'}
              </span>
            </h1>
            <p className="brief-text">
              {ended
                ? `本次行动消灭 ${state.kills} 名敌人，完成 ${state.headshots} 次爆头。`
                : paused
                  ? '调整装备与设置，继续这场行动。'
                  : '穿过长街，占据掩体。\n在烈日与黄沙中，磨练你的每一次射击。'}
            </p>
            <div className="mission-specs">
              <div>
                <Target size={17} />
                <strong>{ended || paused ? state.kills : 12}</strong>
                <span>{ended || paused ? '已击杀' : '击杀目标'}</span>
              </div>
              <div>
                <Crosshair size={17} />
                <strong>
                  {ended
                    ? `${state.shots ? Math.round((state.hits / state.shots) * 100) : 0}%`
                    : 4}
                </strong>
                <span>{ended ? '命中率' : '敌方机器人'}</span>
              </div>
              <div>
                <Shield size={17} />
                <strong>
                  {ended ? state.deaths : paused ? clockText : '2:00'}
                </strong>
                <span>{ended ? '阵亡' : paused ? '剩余时间' : '限时训练'}</span>
              </div>
            </div>
            <div className="difficulty">
              <span>对抗强度</span>
              <div>
                {['新兵', '常规', '老兵'].map((label, i) => (
                  <button
                    key={label}
                    className={difficulty === i ? 'selected' : ''}
                    onClick={() => setDifficulty(i)}
                    aria-pressed={difficulty === i}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
            <button
              className="deploy-button"
              onClick={() => game.current?.start()}
              disabled={!ready}
            >
              <span>
                {paused ? (
                  <Play size={20} />
                ) : ended ? (
                  <RotateCcw size={20} />
                ) : (
                  <Crosshair size={20} />
                )}{' '}
                {ready
                  ? paused
                    ? '继续行动'
                    : ended
                      ? '再次出击'
                      : '进入训练'
                  : '准备装备中…'}
              </span>
              <ArrowUpRight size={23} />
            </button>
            {paused && (
              <button
                className="restart-button"
                onClick={() => game.current?.restart()}
              >
                <RotateCcw size={14} />
                重新开始
              </button>
            )}
            <div className="setting-row">
              <div>
                <Mouse size={15} />
                <span id="sens-label">鼠标灵敏度</span>
                <b>{sensitivity.toFixed(1)}</b>
              </div>
              <Slider
                aria-labelledby="sens-label"
                min={0.3}
                max={2.5}
                step={0.1}
                value={[sensitivity]}
                onValueChange={(v) =>
                  setSensitivity(Array.isArray(v) ? v[0] : v)
                }
              />
            </div>
            <div className="setting-row">
              <div>
                <Volume2 size={15} />
                <span id="volume-label">音效音量</span>
                <b>{volume}%</b>
              </div>
              <Slider
                aria-labelledby="volume-label"
                min={0}
                max={100}
                step={1}
                value={[volume]}
                onValueChange={(v) => setVolume(Array.isArray(v) ? v[0] : v)}
              />
            </div>
            {error && (
              <p className="error-message" role="alert">
                {error}
              </p>
            )}
          </section>
          <div className="scene-label">
            <i />
            <span>沙漠据点</span>
            <small>晴朗 · 38°C · 能见度良好</small>
          </div>
          <footer className="menu-footer">
            <div>
              <kbd>W A S D</kbd>移动<kbd>鼠标</kbd>瞄准 / 射击<kbd>R</kbd>换弹
              <kbd>1 / 2</kbd>切枪<kbd>F</kbd>检视
            </div>
            <span>原创场景 · 建议佩戴耳机</span>
          </footer>
          <div className="mobile-notice">
            建议使用电脑、键盘与鼠标。触屏：左侧移动，右侧转向。
          </div>
        </>
      )}
      {awaitingControls && (
        <section className="ready-screen" aria-label="准备控制">
          <div className="ready-card">
            <Mouse size={28} />
            <h2>准备好再出发</h2>
            <p>锁定鼠标后开始计时。此时敌人不会攻击。</p>
            <button
              className="deploy-button"
              onClick={() => game.current?.capture()}
            >
              锁定鼠标并开始 <ArrowUpRight size={20} />
            </button>
            <button
              className="drag-start"
              onClick={() => game.current?.startDragMode()}
            >
              使用拖动模式开始
            </button>
            <small>
              当前窗口无法锁定鼠标时，可使用右键拖动瞄准、左键射击。触屏使用屏幕控件。
            </small>
          </div>
        </section>
      )}
      {playing && (
        <>
          <div
            className="crosshair"
            style={
              { '--gap': `${5 + state.spread * 45}px` } as React.CSSProperties
            }
          >
            <i />
            <i />
            <i />
            <i />
            <span />
          </div>
          {state.hit > 0 && (
            <div className={`hit-marker ${state.hit > 1 ? 'headshot' : ''}`}>
              ×
            </div>
          )}
          <div className="damage-vignette" style={{ opacity: state.hurt }} />
          <div className="kill-feed">
            {state.feed.map((item) => (
              <div key={item.id}>
                <span>{item.self ? '你' : item.name}</span>
                <Crosshair size={13} />
                <b>{item.self ? item.name : '你'}</b>
                {item.headshot && <Target size={13} />}
              </div>
            ))}
          </div>
          {state.reloading && (
            <div className="reload-status">
              <span>正在换弹</span>
              <i style={{ width: `${state.reloadProgress * 100}%` }} />
            </div>
          )}
          {state.dead && (
            <div className="death-notice">
              <span>已阵亡</span>
              <strong>正在重新部署</strong>
            </div>
          )}
          {state.phase === 'playing' && !state.locked && !state.dead && (
            <div className="capture-hint">拖动模式：按住右键瞄准，左键射击</div>
          )}
          <div className="bottom-hud">
            <div className="vitals">
              <div>
                <span>＋</span>
                <b>{state.health}</b>
                <i style={{ width: `${state.health}%` }} />
              </div>
              <div>
                <Shield size={18} />
                <b>{state.armor}</b>
              </div>
            </div>
            <div className="hud-hint">
              <kbd>SHIFT</kbd>静步 <kbd>C</kbd>蹲伏 <kbd>SPACE</kbd>跳跃{' '}
              <kbd>ESC</kbd>暂停
            </div>
            <div className="weapon-hud">
              <small>
                {state.weapon === 0 ? '01 / AK-47' : '02 / SIDEARM'}
                <span>{state.weapon === 0 ? '突击步枪' : '半自动手枪'}</span>
              </small>
              <div>
                <strong className={state.ammo < 6 ? 'low-ammo' : ''}>
                  {state.ammo}
                </strong>
                <span>/ {state.reserve}</span>
              </div>
            </div>
          </div>
          <div className="touch-controls" hidden={awaitingControls}>
            <div className="touch-pad">
              {[
                ['KeyW', '↑'],
                ['KeyA', '←'],
                ['KeyS', '↓'],
                ['KeyD', '→'],
              ].map(([code, label]) => (
                <button
                  key={code}
                  aria-label={code}
                  onPointerDown={() => game.current?.setKey(code, true)}
                  onPointerUp={() => game.current?.setKey(code, false)}
                  onPointerLeave={() => game.current?.setKey(code, false)}
                >
                  {label}
                </button>
              ))}
            </div>
            <div className="touch-fire">
              <button
                onPointerDown={() => game.current?.setFire(true)}
                onPointerUp={() => game.current?.setFire(false)}
                onPointerLeave={() => game.current?.setFire(false)}
              >
                开火
              </button>
              <button onClick={() => game.current?.reload()}>换弹</button>
            </div>
          </div>
        </>
      )}
    </main>
  );
}
