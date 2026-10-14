# ISO-Pro: plano de criação do app

Versão 1.0, 2026-10-14. Baseado na análise de `docs/analysis/blackmagic-camera.md`
(fase 1: fontes públicas; fase 2: análise binária do Blackmagic Camera 3.5.0.0066 com REA).

> Sala limpa: este plano usa a análise só como **especificação de comportamento**.
> Nenhum código, string, LUT, curva ou recurso gráfico da Blackmagic entra no ISO-Pro.

---

## 1. Visão do produto

**O app de cinema profissional que funciona no celular que você tem.**

A Blackmagic filtra aparelhos por `uses-feature` rígidos e minSdk 33, prende o fluxo
ao Blackmagic Cloud e ao Resolve, e não tem waveform nem vectorscope no Android. O
ISO-Pro ataca exatamente essas lacunas:

| Diferencial | Por que importa | Evidência |
|---|---|---|
| **Funciona em intermediários** (Galaxy A, Moto G, Redmi Note…) e se adapta ao aparelho | É onde está a maioria dos criadores | Blackmagic exige `manual_post_processing` + `opengles.aep` + Android 13 |
| **Log em quatro níveis** (fabricante → ISP → HLG → Flat) | Log "de verdade" até onde o hardware permite, sem mentir em 8 bits | Seção 7.2 da análise |
| **Scopes completos**: waveform, vectorscope, RGB parade | Ferramenta básica de exposição em log | Ausentes no binário Android da Blackmagic |
| **Fluxo aberto**: FCPXML/EDL/ALE, S3/Drive/Frame.io | Não prende a um editor nem a uma nuvem | Blackmagic usa nuvem e protocolo proprietários |
| **APV** como codec intra profissional | Equivalente aberto ao ProRes, sem royalties | `VideoCodecFormat` da Blackmagic inclui APV |

**Público inicial:** videomakers e filmmakers mobile com Android intermediário ou topo
de linha. **Plataforma:** Android primeiro; iOS só depois do produto validado.

---

## 2. Escopo: paridade, superação e o que não fazer

| Área | Blackmagic Camera (REA) | ISO-Pro | Fase |
|---|---|---|---|
| Controles manuais (ISO, obturador vel./ângulo, WB K+tint, foco, íris, zoom) | ✓ | ✓, com APIs do Android 16 e fallback | 1 |
| Prioridade de ISO/obturador (`CONTROL_AE_PRIORITY_MODE`) | ✓ | ✓ onde houver | 1 |
| H.264 / HEVC 10 bits | ✓ | ✓ | 1 |
| APV / AV1 | ✓ | ✓ onde houver encoder | 2 |
| Log do fabricante / log próprio / HLG | ✓ (só aparelhos da lista) | ✓ em 4 níveis | 1–2 |
| Histograma, zebra, false color, peaking, grades, guias | ✓ | ✓ | 1 |
| **Waveform, vectorscope, RGB parade** | ✗ | ✓ | 2 |
| LUT `.cube` no monitor / gravada | ✓ | ✓ | 1 (monitor) / 2 (gravada) |
| Proxy simultâneo | ✓ | ✓ | 2 |
| Slate, timecode, metadados QuickTime | ✓ | ✓ | 2 |
| Time-lapse, desqueeze anamórfico, estabilização | ✓ | ✓ | 2 |
| Presets de foco/zoom e rack focus | ✓ | ✓ | 2 |
| Áudio: mic interno/USB/BT, 48 kHz, medidores | ✓ | ✓ | 1 |
| API REST + mDNS + multicâmera via WebSocket | ✓ (203 endpoints) | ✓, núcleo de ~40 endpoints | 3 |
| Wear OS | ✓ | ✓ | 3 |
| Tilta Nucleus (BLE + USB MIDI), Tentacle | ✓ | ✓ | 3 |
| Gimbal (Insta360 via SDK) | ✓ | Avaliar SDKs oficiais (Insta360, DJI) | 4 |
| Saída HDMI com clean feed | ✓ | ✓ | 4 |
| Live SRT / RTMP | ✓ (GStreamer) | ✓ (libsrt + TS próprio) | 4 |
| Upload de proxy na nuvem | Blackmagic Cloud | S3, Drive, Frame.io | 4 |
| Correção de cor ao vivo (lift/gamma/gain) | ✓ (REST) | Avaliar | 5 |
| **Não fazer** | Blackmagic Cloud, chat, Blackmagic Log, controle de câmeras de hardware deles, PYXIS | — | — |

---

## 3. Arquitetura

### 3.1 Princípio
A análise mostrou que a Blackmagic mantém o Kotlin "fino" e coloca o caminho quente
(preview, cor, LUT, encode, áudio) em C++. O ISO-Pro faz o mesmo **desde o MVP**:
refatorar o pipeline de Kotlin para nativo depois sai muito mais caro.

### 3.2 Visão geral

```
┌──────────────────────────── Kotlin / Compose ────────────────────────────┐
│ UI (HUD, menus, presets)   ViewModels   Settings (DataStore/Room)         │
│ CameraController (Camera2)   CapabilityProbe   AudioRouter   Storage      │
│ RemoteServer (Ktor) · Discovery (NSD) · Accessories (BLE/MIDI/Wear)       │
└───────────────▲─────────────────────────────────────────────▲────────────┘
                │ JNI (comandos, estado)                      │ eventos
┌───────────────┴──────────────────── C++ / NDK ──────────────┴────────────┐
│ FramePump: AImageReader/SurfaceTexture → AHardwareBuffer                  │
│ RenderGraph (GLES 3.2; Vulkan depois):                                    │
│   ├─ ColorPipeline: curva log (nível 3/4), LUT 3D, desqueeze              │
│   ├─ Monitor: zebra, false color, peaking, guias  ──► Surface de preview  │
│   ├─ Scopes (compute): histograma, waveform, vectorscope, parade @15 Hz   │
│   └─ Encode surfaces: principal + proxy                                   │
│ Encoder: AMediaCodec (H.264 / HEVC Main10 / AV1 / APV)                    │
│ Audio: AAudio/Oboe → PCM 48 kHz → AAC ou PCM                              │
│ Muxer: MediaMuxer (fase 1) → writer MP4/MOV próprio com tmcd + metadados  │
└───────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Módulos Gradle

| Módulo | Responsabilidade |
|---|---|
| `:app` | Activity, navegação, injeção de dependências |
| `:feature:camera` | HUD e telas de câmera (Compose) |
| `:feature:settings`, `:feature:media` | Configurações, presets, galeria e gestor de proxies |
| `:core:capabilities` | Detecção do aparelho → `DeviceProfile` + banco de *quirks* |
| `:core:camera` | Sessão Camera2, `CaptureRequest`, mapeamento de controles |
| `:core:pipeline` (C++) | RenderGraph, encoder, muxer, áudio, JNI |
| `:core:color` | Especificação ISO-Pro Log, LUTs, matemática de cor (compartilhada Kotlin/C++) |
| `:core:storage` | MediaStore, SAF/USB OTG, nomes de clipe, verificação de espaço |
| `:core:remote` | Servidor REST (Ktor), WebSocket, mDNS, protocolo multicâmera |
| `:core:accessories` | BLE (Tilta, Tentacle), USB MIDI, Wear OS |
| `:core:streaming` | SRT/RTMP, MPEG-TS |

### 3.4 Plataforma
- **minSdk 29** (Android 10): abre a base de intermediários. Os recursos novos são
  detectados em tempo de execução: `DynamicRangeProfiles` (API 33), `FLASH_STRENGTH_LEVEL` (35),
  WB em Kelvin/tint e prioridade de AE (36), APV (36).
- **targetSdk/compileSdk 37.**
- Kotlin 2.x, Compose + Material 3, Coroutines/Flow, Hilt, DataStore e Room.
- NDK r28+, CMake, C++20.

### 3.5 Bibliotecas abertas (licenças compatíveis)
Ktor e Netty (Apache-2.0), JmDNS ou `NsdManager` (Apache-2.0/plataforma), JCodec como
referência de boxes MP4 (BSD-2), libsrt (MPL-2.0), Oboe (Apache-2.0),
libjpeg-turbo (BSD). **Evitar GStreamer** (LGPL e pesado): só se SRT/RTMP próprios
não fecharem.

---

## 4. Núcleo técnico

### 4.1 `CapabilityProbe` → `DeviceProfile`
Roda na primeira abertura (e depois de atualizações do sistema), em menos de 1 s, e é salvo em cache.

| Leitura | De onde | Usado para |
|---|---|---|
| Nível de hardware, capacidades | `INFO_SUPPORTED_HARDWARE_LEVEL`, `REQUEST_AVAILABLE_CAPABILITIES` | Manual, RAW, `MANUAL_POST_PROCESSING`, 10 bits |
| Faixas de ISO, exposição, fps | `SENSOR_INFO_*`, `CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES` | Limites dos controles |
| Perfis HDR | `REQUEST_AVAILABLE_DYNAMIC_RANGE_PROFILES` | Nível 3 de log, HLG |
| Curva de tom | `TONEMAP_AVAILABLE_TONE_MAP_MODES`, `TONEMAP_MAX_CURVE_POINTS` | Nível 2 de log |
| WB Kelvin, prioridade AE | `COLOR_CORRECTION_*`, `CONTROL_AE_AVAILABLE_PRIORITY_MODES` | Controles nativos ou fallback |
| Câmeras físicas | `getPhysicalCameraIds`, `LENS_INFO_*` | Troca de lente |
| Encoders | `MediaCodecList` (perfis, níveis, bitrates) | Codecs, resoluções e bitrates oferecidos |
| Estabilização | `LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION`, `CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES` | Opções de estabilização |
| Térmico | `PowerManager.getCurrentThermalStatus` (API 29) e `getThermalHeadroom` (API 30+) | Orçamento de recursos |

O banco de *quirks* (JSON versionado, atualizável sem release) corrige aparelhos
que mentem nas capacidades. A tela de diagnóstico permite exportar o
`DeviceProfile` anonimizado.

### 4.2 Controles manuais
- **Exposição:** `SENSOR_EXPOSURE_TIME` + `SENSOR_SENSITIVITY` + `SENSOR_FRAME_DURATION`.
  O ângulo do obturador é convertido em tempo pelo fps. Shutters *flicker-free*
  calculados para 50/60 Hz.
- **WB:** no Android 16+, `COLOR_CORRECTION_COLOR_TEMPERATURE/TINT`. Antes disso,
  `COLOR_CORRECTION_GAINS` + `TRANSFORM`, a partir de uma tabela Kelvin → ganhos calibrada.
- **Foco:** `LENS_FOCUS_DISTANCE` (dioptrias) com mapa para metros quando
  `LENS_INFO_FOCUS_DISTANCE_CALIBRATION` = CALIBRATED. Três presets e rack com curva de
  tempo interpolada por quadro.
- **Prioridade de AE** no Android 16+ (`CONTROL_AE_PRIORITY_MODE`). Antes disso, uma
  emulação em software (AE própria sobre o histograma).

### 4.3 Cor e log: os quatro níveis
Implementação da seção 7.2 da análise:

1. **Fabricante:** ativação via chaves ou extensões do fabricante, quando o banco de quirks souber como.
2. **ISP:** `TONEMAP_MODE_CONTRAST_CURVE` com a curva ISO-Pro Log reamostrada para
   `TONEMAP_MAX_CURVE_POINTS`, mais 10 bits.
3. **GPU:** captura em HLG10, depois HLG → linear de cena → ISO-Pro Log no `ColorPipeline`.
4. **Flat** em 8 bits: curva suave, nunca chamada de "Log".

Para todos os níveis: `EDGE_MODE` e NR no mínimo, AE/AWB travados ao gravar, LUT
de monitor ligada e false color/zebra calibrados para a curva.

**ISO-Pro Log** terá especificação pública (fórmula, cinza médio, faixa de stops), LUT
`.cube` para Rec.709 e para *Rec.2020 PQ*, e nome registrado no metadado do clipe.

### 4.4 Gravação
- **Encoders:** HEVC Main10 (padrão quando houver 10 bits), H.264 High (compatibilidade),
  APV e AV1 quando o `MediaCodecList` os anunciar. Bitrate padrão em 4K30 HEVC 10 bits:
  100 Mbps (faixa de 50 a 150).
- **Proxy:** segundo encoder H.264 em 1080p a 8–12 Mbps, alimentado pela mesma textura.
  Desliga automaticamente sob pressão térmica.
- **Contêiner:** MP4 via `MediaMuxer` na fase 1. Na fase 2 entra um **writer MP4/MOV
  próprio**, necessário para a track `tmcd`, metadados QuickTime (slate, lente, curva) e APV.
- **Gravação robusta:** arquivo fragmentado ou com índice parcial periódico (se o
  app morrer, o clipe é recuperável) e checagem de espaço e velocidade de escrita antes de gravar.
- **Áudio:** Oboe/AAudio, 48 kHz, até 4 canais quando o dispositivo permitir, AAC
  256 kbps ou PCM 24 bits (MOV). Roteamento por `AudioDeviceInfo` (USB e BT).

### 4.5 Monitoramento e scopes
Shaders GLES 3.2 sobre a textura de preview:
- Zebra (limiar configurável e faixa de pele), false color (escala para log e
  para Rec.709) e peaking (Sobel em luma, cor configurável).
- **Compute** com amostragem reduzida (ex.: 1/4 da resolução, 15 Hz): histograma
  RGB/luma, waveform (luma e parade) e vectorscope com alvos de Rec.709.
- Orçamento de GPU: preview + scopes em até **4 ms/quadro** num Adreno ou Mali intermediário.

### 4.6 Remoto e multicâmera (fase 3)
- Servidor Ktor/Netty em `/api/v1` com um núcleo de ~40 endpoints: transporte,
  formato, exposição, WB, foco, monitoramento, áudio, slate, timecode e mídia.
  Documentação OpenAPI servida pelo app.
- **Decisão pendente (seção 9):** espelhar ou não o formato público
  `/control/api/v1` da Blackmagic, para interoperar com ferramentas existentes.
- Descoberta por `NsdManager` (`_isopro._tcp`), estado e preview remoto por WebSocket
  (JPEG 720p a 15 fps no MVP do remoto; WebRTC depois).
- Start/stop sincronizado: relógio comum por troca NTP simplificada e gravação
  agendada para um instante futuro. Meta: ±1 quadro em 4 aparelhos.

### 4.7 Desempenho e térmico
- Orçamento por quadro em 4K30: captura → GPU → encode sem cópias para a CPU
  (`AHardwareBuffer`/Surfaces).
- Estados térmicos (`getCurrentThermalStatus`, refinado por `getThermalHeadroom` na API 30+): em *moderate*, scopes vão a 5 Hz; em
  *severe*, o proxy desliga e o preview cai para 1080p; em *critical*, o app avisa e
  encerra o clipe com segurança.

---

## 5. UX
- HUD no padrão de câmera de cinema: barra superior (fps, obturador, íris, WB, ISO,
  timecode, mídia e bateria), barra inferior (codec, resolução, áudio) e toque para editar.
- Até 3 botões programáveis, presets salvos/compartilháveis (arquivo `.isopreset`).
- **Modo simples** (auto com travas) e **modo pro**; o nível de log e as capacidades
  aparecem em linguagem clara ("Seu aparelho grava Log 10 bits via HLG").
- Acessibilidade: tamanhos dinâmicos, alto contraste e feedback tátil nos controles.

---

## 6. Fases, entregas e critérios de pronto

Estimativas para um time de **3 pessoas** (2 Android/Kotlin, 1 C++/gráficos).
São ordens de grandeza, a reavaliar após a fase 0.

| Fase | Duração | Entregas | Critério de pronto |
|---|---|---|---|
| **0 — Fundação** | 3 sem | Repo multi-módulo, CI (build, lint, testes, NDK), `CapabilityProbe` + tela de diagnóstico, protótipo do FramePump → preview GLES | Probe roda em 6 aparelhos da matriz; preview 4K a 30 fps sem cópia para a CPU |
| **1 — MVP** | 10 sem | Controles manuais completos; HEVC 10 bits e H.264; log níveis 2–4; histograma, zebra, false color, peaking; LUT no monitor; áudio 48 kHz com medidores; galeria; presets | 30 min de 4K30 sem perder quadros em Pixel 8 e S24; 1080p30 log nível 3 ou 4 num intermediário; crash-free ≥ 99,5% no beta fechado |
| **2 — Pro** | 8 sem | Waveform, vectorscope e parade; LUT gravada; proxy; writer MOV com `tmcd` e metadados; slate; time-lapse; desqueeze; rack focus; APV/AV1; exportação FCPXML/EDL/ALE | Clipe abre conformado com timecode e metadados no Resolve, Premiere e Final Cut |
| **3 — Conectado** | 8 sem | API REST + OpenAPI, mDNS, controle multicâmera (1+N), preview remoto, Wear OS, Tilta Nucleus, Tentacle | 4 aparelhos com start/stop a ±1 quadro; acessórios testados em hardware real |
| **4 — Saídas** | 6 sem | HDMI com clean feed, SRT e RTMP, upload de proxy (S3/Drive/Frame.io), avaliação de gimbal | Live SRT de 1 h estável; HDMI 4K30 com áudio |
| **5 — Expansão** | — | Correção de cor ao vivo, Vulkan, foto RAW/DNG, iOS | Decisão de negócio após o lançamento |

**Lançamento público:** depois da fase 2 (o MVP sozinho não supera a Blackmagic em
nada visível; as fases 1 e 2 juntas, sim: scopes, log em intermediários e fluxo aberto).

---

## 7. Qualidade e testes

- **Matriz de aparelhos (mínimo):** Pixel 8 e 9, Galaxy S24/S25, **Galaxy A56/A57**,
  Moto G (2025), Redmi Note 14 e um Snapdragon 7-series. Um aparelho por nível de log.
- **Testes automatizados:**
  - unitários (Kotlin/C++) para matemática de cor, conversões de obturador e WB, e parser `.cube`;
  - *golden images* dos shaders (zebra, false color, scopes) comparadas com tolerância;
  - testes de contrato da API REST contra o OpenAPI;
  - validação dos arquivos gerados (`ffprobe`/MediaInfo no CI: codec, bit depth,
    `tmcd`, metadados).
- **Testes de resistência:** gravação de 60 min, ciclos de start/stop (500x),
  cartão ou disco lento, bateria baixa e cenário térmico (câmara quente ou sol).
- **Beta fechado** com 50–100 videomakers, com telemetria opcional de `DeviceProfile` e falhas.

---

## 8. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Aparelhos que mentem nas capacidades do Camera2 | Alta | Alto | Banco de quirks remoto, diagnóstico no app, matriz real |
| Térmico em 4K + proxy + scopes | Alta | Alto | Orçamento por estado térmico (4.7), medição desde a fase 0 |
| Curva no ISP (nível 2) rara em intermediários | Média | Médio | Níveis 3 e 4 garantem oferta; comunicação honesta na UI |
| `MediaMuxer` limitado (sem `tmcd`, APV) | Certa | Médio | Writer MOV próprio na fase 2 |
| Encoder APV/AV1 ausente na maioria | Alta | Baixo | Opcional, só quando detectado |
| Concorrer com app gratuito | Certa | Alto | Diferenciais da seção 1; modelo freemium (seção 9) |
| Risco jurídico (engenharia reversa, marcas) | Baixa | Alto | Sala limpa, revisão jurídica antes de expor compatibilidade REST |

---

## 9. Decisões em aberto (do dono do produto)

1. **Monetização:** freemium (núcleo grátis; scopes, multicâmera e streaming pagos)
   ou pago único? Isso afeta o que entra no MVP.
2. **Compatibilidade com a API REST pública da Blackmagic** (`/control/api/v1`): ganho de
   interoperabilidade contra o risco jurídico e o custo de manter.
3. **minSdk 29 ou 31:** 29 alcança mais intermediários antigos, 31 simplifica o código.
4. **Nuvem padrão:** Frame.io, Google Drive ou S3 genérico primeiro.
5. **iOS:** quando e com qual equipe.

---

## 10. Primeiro sprint (fase 0, semanas 1–2)

1. Criar o projeto Android multi-módulo (seção 3.3) com Gradle version catalog,
   CMake/NDK e CI no GitHub Actions (build, lint, testes unitários).
2. `:core:capabilities`: ler todas as chaves da tabela 4.1 e serializar o `DeviceProfile` em JSON.
3. Tela de diagnóstico: mostra o perfil, o nível de log possível e permite exportar.
4. `:core:pipeline`: abrir câmera → `SurfaceTexture` → shader passthrough → preview,
   medindo a latência e o tempo de GPU por quadro.
5. Especificação v0 do ISO-Pro Log (fórmula + LUT para Rec.709) em `docs/color/`.
6. Montar a matriz de aparelhos (comprar ou emprestar) e o roteiro de testes manuais.

Saída do sprint: APK interno que roda o diagnóstico e o preview em todos os
aparelhos da matriz, e dados reais para recalibrar as estimativas da seção 6.
