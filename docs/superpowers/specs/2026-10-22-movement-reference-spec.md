# Hero movement reference spec: Super Mario 64 (and Ratchet & Clank) → PlatformerMotor

Date: 2026-10-22. Status: research reference for the movement rework. Nothing in the repo has been changed by it.

## Sources and clean-room note

- Super Mario 64 decompilation: <https://github.com/n64decomp/sm64>. Files read: `src/game/mario.c`, `mario_step.c`, `mario_actions_moving.c`, `mario_actions_airborne.c`, `mario_actions_stationary.c`, `mario_actions_automatic.c`, `src/engine/surface_collision.c`, `surface_load.c`.
- Ratchet & Clank (2002) decompilations:
  - Lombyte: <https://github.com/lombyte-project/Lombyte>
  - OpenRAC rac1-decomp: <https://github.com/OpenRAC/rac1-decomp>
- Ratchet & Clank control lists: <https://ratchetandclank.fandom.com/wiki/Going_Commando_controls>

**Clean-room rule (same principle as DEC-049/DEC-050):**
- The decompiled code belongs to Nintendo and Insomniac. It was read only to understand behaviour, from a scratch copy outside the repo.
- This document describes *what the games do*: states, transitions, conditions and tuning numbers, in our own words.
- It contains no code, no function bodies and no variable-for-variable structure. Engineers implement from this prose, not from the decomp, and must not open the decomp while writing the GDScript.
- Game mechanics and numeric tuning are recorded here; code expression is not.

**Units.**
- SM64 runs its physics at 30 Hz. One SM64 unit is about 1 cm (Mario's collision cylinder is 160 units tall).
- Conversions:
  - speed in units/frame × 0.30 = m/s;
  - acceleration in units/frame per frame × 9 = m/s²;
  - distance in units × 0.01 = m.
- **Hero scale.** Our hero is about 1.8 m tall, so the "hero" columns multiply by k = 1.8 / 1.6 = 1.125. That keeps every move the same number of body-lengths and the same duration. Times do not scale.

---

## 1. The overall model

### 1.1 One action at a time
- Mario is always in exactly one **action** (about 200 of them). Actions are grouped as stationary, moving, airborne, automatic (ledges, poles, hanging), submerged, cutscene and object.
- Each physics frame:
  1. read the inputs: buttons, stick and the geometry around Mario;
  2. run the current action's handler. A handler may switch to another action, and the new handler runs **in the same frame**, until one handler finishes without switching. A jump pressed on the landing frame therefore takes off that same frame, with no dead frame.
- **Every handler, every frame:**
  - decides its transitions first: cancels and exits;
  - updates the speed;
  - performs one ground or air "step" against the world;
  - reacts to the step result: landed, left the ground, hit a wall or grabbed a ledge;
  - **sets the animation for this action, every frame**.
- Damage, interactions (enemies, hazards) and special floors never push velocity "from outside". They **switch the action**: to a knockback, a bonk or a burn. An action never keeps running while something else moves Mario.

### 1.2 Stick → intended yaw and intended magnitude
- The stick's raw magnitude (0..64) is **squared**, then scaled so a full tilt gives an intended magnitude of 32 units/frame. This is 9.6 m/s, or 10.8 m/s for the hero.
  - Small tilts are much slower than linear: half tilt gives a quarter speed. This makes careful walking easy on an analogue stick.
- **Intended yaw** = the stick angle + the camera's yaw. With no stick input, intended yaw = the current facing.

### 1.3 Facing vs velocity (the key difference from our motor)
- On the ground Mario has a **scalar forward speed** and a **facing yaw**. Velocity is always facing × forward speed.
  - The stick turns the *facing* toward the intended yaw at a fixed rate: 11.25° per frame, about 340°/s, whatever the speed.
  - Speed then moves along the new facing. So he **always faces the way he moves on the ground**, and visible sliding sideways cannot happen.
- Sliding states (butt slide, stomach slide, dive slide) use a separate slide velocity vector. In these states the facing is pulled toward the slide direction (or exactly against it) by about 2.8° per frame.
- In the air, ordinary jumps **keep the facing fixed**:
  - The stick changes forward speed along the facing.
  - It adds a small sideways drift that does not build up.
  - Only a few special actions turn the facing in mid-air.

**Consequence for us:** `player._update_facing` sets `_facing_3d` to the stick direction **instantly**, every frame (player.gd:437-442). Meanwhile the motor rotates the *velocity* at a finite rate, and in SLIDE and AIR barely rotates it at all (platformer_motor.gd:229, 365). So the model regularly faces one way while the body moves another way. That reads as gliding or moonwalking. See §5.3.

---

## 2. Ground

### 2.1 Walking and running

| Quantity | SM64 (raw) | SM64 metric | Hero (×1.125) | Ours today |
|---|---|---|---|---|
| Target speed at full tilt | 32 u/f | 9.6 m/s | 10.8 m/s | RUN 8.5, builds to 11.0 m/s (BOOST) |
| Absolute ground cap | 48 u/f | 14.4 m/s | 16.2 m/s | none (long jump landing clamps to 11) |
| Instant start speed (entering walk) | min(stick, 8) u/f | up to 2.4 m/s | 2.7 m/s | `start_speed3d` 3.5 m/s |
| Accel at 0 speed | +1.1 u/f/f | 9.9 m/s² | 11.1 m/s² | `accel3d` 70 m/s² (constant) |
| Accel near the target | +1.1 − v/43 | ~3.2 m/s² at 9.6 m/s | ~3.6 m/s² | 70 m/s² |
| 0 → full run time | ~48 frames | ~1.6 s | 1.6 s | ~0.1 s, then a 0.4 s delay + 0.8 s ramp to boost |
| Over the target (flat floor only) | −1 u/f/f | −9 m/s² | −10 m/s² | moves toward the target at 70 |
| Facing turn rate | 0x800 per frame | ~340°/s | same | velocity rotates at 20 rad/s (1146°/s); the facing snaps |

**Notes:**
- **The acceleration curve** is a "drag-limited" curve: fast pickup, then a slow approach to top speed. Most of the "weight" of Mario's run comes from the last 30% of speed taking about 1 s.
- **Our boost** (8.5 → 11 m/s after 0.4 s running straight) is a reasonable stand-in for that slow tail. The main gap is our nearly instant acceleration.
- **Body tilt while running:**
  - The torso pitches forward with speed.
  - It rolls into turns by an amount proportional to (yaw change this frame × forward speed), capped at 30°, and eased at about 5.6° per frame.
  - This is purely visual, and it is a big part of why turns feel physical.

### 2.2 Releasing the stick, braking, turning around
- **Stick released at ≥ 4.8 m/s** (5.4 m/s hero) → **brake/skid**:
  - decelerates at 36 m/s² (40.5 m/s² hero) on normal floors, with a skid animation and dust;
  - at 0 → "brake stop" (a short recovery pose) → idle;
  - any stick input or jump cancels it back to the normal actions.
- **Stick released below 4.8 m/s** → **decelerating**:
  - −9 m/s² (≈ 0.25–0.5 s to stop);
  - the **walk animation keeps playing, slowing with the speed**;
  - then idle.
- **Turnaround:**
  - Trigger: the stick is held more than ~100° away from the facing while the speed is ≥ 4.8 m/s.
  - Phase 1: brake at 36 m/s², with "skid, part 1" while the speed is ≥ 5.4 m/s and "part 2" below that.
  - Phase 2: at 0 → "finish turning around": the facing flips 180° and the hero walks off at 2.4 m/s in the new direction.
  - **Jump during either phase = side flip.**
  - Below 4.8 m/s there is no turnaround: the 340°/s facing turn simply pivots him on the spot.
- **Ours:**
  - SKID triggers at > 150° and ≥ 6 m/s and lasts a fixed 0.18 s, then exits at 5 m/s along the new direction. That is fine, and snappier than SM64.
  - With no stick we stop at 90 m/s² (about 0.1 s) with no decel state or animation. SM64's 9 m/s² glide-to-stop *with the walk cycle slowing down* is what sells the weight.

### 2.3 Walls while walking
- Wall collision is a horizontal push-out of two horizontal circles:
  - radius 0.24 m at 0.30 m above the feet;
  - radius 0.50 m at 0.60 m above the feet (hero: 0.27/0.34 m and 0.56/0.68 m).
- Walls only ever push sideways. There is no vertical response, so walls never lift or stop a fall.
- **Walking into a wall:**
  - The forward speed is clamped to 1.8 m/s (2.0 m/s hero).
  - If the wall is roughly head-on (within ~20°), the **push** animation plays.
  - Otherwise a **side-step** animation plays along the wall, its rate scaled by the distance actually moved. The body slides along the wall face, the model turns to face the wall, and dust spawns.
- Glancing walls (within ±30° of parallel to the facing) are ignored for "hit wall" purposes. You just slide along them.

### 2.4 Steps, floor snapping, edges
- A ground step is split into **4 quarter-steps**. Each quarter-step:
  1. moves horizontally by velocity × floor normal Y (steep floors slow horizontal travel);
  2. resolves walls;
  3. finds the floor under the new spot.
- **Stepping up:**
  - The floor search accepts floors up to 0.78 m above the feet.
  - But the lower wall probe at 0.30 m blocks any lip taller than about 0.3 m.
  - Effective step-up ≈ 0.3 m (hero 0.34 m). Ours: `floor_snap_length` 0.35 (main.gd:139). Godot's CharacterBody3D has **no step-up**: a lip is climbed only if the capsule's rounded bottom rides over it (roughly a quarter of the capsule radius). To get SM64-like stairs, add an explicit step-up (try the move raised 0.34 m, then snap down) or build stairs as ramps in collision.
- **Snapping down:**
  - If the floor under the next spot is within 1.0 m below, Mario is placed on it. Walking down stairs and slopes never goes airborne.
  - More than 1.0 m below → "left ground" → the **freefall** action with the fall animation, keeping the forward speed.
  - Ours snaps only 0.35 m. That is fine for a capsule, but keep it at ≥ 0.4 m (one stair riser + margin) so stairs and slope breaks never flicker the air state.
- **Headroom:** a quarter-step into a space with less than 1.6 m between floor and ceiling is refused, so he stops.
- **Slow edge climb-down:**
  - Trigger: walking slowly (< 3 m/s) toward a drop of more than 1.6 m where a cliff face is right behind the feet.
  - Mario turns around and **climbs down into a ledge hang** instead of falling.
  - This is a big comfort feature for open courses.

### 2.5 Slopes
Floors carry a surface class: not-slippery, default, slippery or very slippery. The thresholds are by floor angle:

| Class | Counts as "slope" (gravity pulls speed) | Forces a slide (you can't walk) | "Steep" for jumping (facing uphill) |
|---|---|---|---|
| Very slippery (ice) | > 5° | > 10° | > 15° |
| Slippery | > 10° | > 20° | > 20° |
| Default | > 15° | > 38° | > 30° |
| Not slippery | > 20° | never | > 30° |

- **On a slope while walking:**
  - The forward speed gains (downhill) or loses (uphill) a per-frame amount: 1.7 u/f/f for default floors, ≈ 15 m/s² × sin(slope).
  - Not-slippery floors give 0.
- **Forced slide:**
  - Entered on a slippery-for-its-class floor when facing downhill, moving backward, or on a "slide level".
  - It becomes a **butt slide** (facing downhill) or a **stomach slide** (facing uphill).
  - The slide velocity gains about 7 u/f/f × steepness down the slope (≈ 63 m/s² × sin), multiplied each frame by ~0.92 (default), 0.96 (slippery) or 0.98 (ice), plus a small stick bonus. That gives a natural terminal speed.
  - The stick steers the slide by rotating the slide vector a little each frame.
  - The slide ends when the floor flattens and the speed drops below 1.2 m/s.
  - A jump is allowed after 5 frames.
- **Too steep to stand on** (floor normal Y < 0.29, about 73°): landing there pushes him off at ±4.8 m/s into freefall.
- **Jumping while facing up a steep slope** turns into a **steep jump**: a weaker jump angled down the slope. You cannot jump-climb a slope you cannot walk.
- **Ours:**
  - We have no slope states.
  - Above `floor_max_angle` 50° (main.gd:140), Godot reports "not on floor", so the motor stays in AIR with the fall pose while `move_and_slide` slides the capsule down the face. That is the textbook "stuck in a pose and sliding" case (§5.3).

### 2.6 Crouch, crouch slide
- Crouch is a stationary action.
- Pressing crouch while walking → **crouch slide**:
  - decelerates as a slide;
  - for the first 30 frames (1 s), jump at > 3 m/s gives a **long jump**;
  - jump otherwise gives a normal jump;
  - attack at ≥ 3 m/s gives a slide kick.
- Crouching while still + jump → **backflip**.
- **Ours:** CROUCH and SLIDE with similar rules. The long jump needs SLIDE, or CROUCH with ≥ 5 m/s. Good.

---

## 3. Air

### 3.1 Gravity, terminal velocity, variable height

| Quantity | SM64 metric | Hero | Ours today |
|---|---|---|---|
| Gravity (normal) | 36 m/s² (4 u/f/f), the same rising and falling | 40.5 m/s² | rise 35.5, fall 63.1 m/s² (`jump_height3d` 2.3, rise 0.36 s, fall 0.27 s) |
| Gravity (long jump, slide kick) | 18 m/s² | 20.3 m/s² | rise/fall × 0.45 |
| Terminal velocity | 22.5 m/s | 25.3 m/s | 36 m/s (`max_fall_speed` 24 × 1.5) |
| Variable height | while rising faster than 6 m/s with jump released, the vertical speed is **divided by 4 each frame**: a near-instant cut | same | × 0.45 once on release (`jump_cut_factor`) |
| Apex hang | none | — | gravity × 0.5 near the apex while held |

- SM64's symmetric gravity is floatier on the way down than ours.
- Our heavier fall gravity is a modern choice; Odyssey-like games use it. It is fine to keep.
- If "Mario 64 feel" is the target, bring the fall gravity down toward 40–45 m/s² and the terminal speed to about 25 m/s.

### 3.2 Jump table
Vertical launch speed uses this pattern: base + 0.25 × forward speed for single and double jumps only. So running jumps go higher. Heights are v²/2g with no early release.

| Jump | Entry | Launch vy (SM64 / hero) | Apex (SM64 / hero) | Horizontal |
|---|---|---|---|---|
| Single | jump from ground | 12.6 m/s + 0.25·v | standing 2.2 / 2.5 m; full run 3.1 / 3.5 m | forward speed × 0.8 |
| Double | jump during the landing of a single (window below) | 15.6 + 0.25·v | standing 3.4 / 3.8 m; full run 4.5 / 5.1 m | × 0.8 |
| Triple | jump during the landing of a double, **forward speed > 6 m/s (6.75 hero) at that moment** | 20.7 | 6.0 / 6.7 m | × 0.8; flip animation; no ledge grab during it |
| Backflip | crouching (stationary) + jump | 18.6 | 4.8 / 5.4 m | −4.8 m/s (backwards) |
| Side flip | jump during a turnaround | 18.6 | 4.8 / 5.4 m | 2.4 m/s; facing snaps to the stick |
| Wall kick | see §4.2 | 18.6 | 4.8 / 5.4 m | at least 7.2 m/s (8.1 hero) away from the wall |
| Long jump | crouch-slide + jump within 1 s, speed > 3 m/s | 9.0 (10.1) | 2.25 / 2.5 m (half gravity) | forward × 1.5, capped at 14.4 m/s (16.2); about 1 s airtime, ~14 m (hero ~16 m) |
| Dive | attack in the air at > 8.4 m/s, or on the ground at ≥ 8.7 m/s | ground: 6 m/s | low | forward + 4.5 m/s, capped at 14.4; pitches nose-down over time; lands into a belly slide (jump or attack → rollout) |
| Ground pound | crouch in the air | rises ~1.1 m (1.24) over 10 frames while spinning | — | horizontal speed zeroed; after the spin animation (+4 frames) it falls from −15 m/s with normal gravity to terminal |

**Jump chaining window:**
- Every landing action lasts **4 frames (0.13 s)**; the long-jump landing lasts 6.
- On every frame of a landing, a "double jump timer" is refilled to **5 frames**.
- A jump during the landing, or during the walk that follows while that timer is still running, chains to the next jump.
- In practice the window is about **0.25–0.3 s from touchdown**. Ours (`CHAIN_WINDOW`) is 0.15 s, which is tight on keyboard. Use 0.25 s.
- The triple jump also requires a single → double → triple order with no other action in between, and the speed gate above.

### 3.3 Air steering
In ordinary jumps the facing is fixed. Each frame:
1. The forward speed decays toward 0 by 3.15 m/s² (3.5 hero): a light air drag.
2. The stick adds up to 13.5 m/s² (15.2) × tilt × cos(the angle between the stick and the facing) to the forward speed. Pushing back slows you down and can make you drift backward, down to −4.8 m/s.
3. The stick adds a **sideways velocity offset** of up to 3 m/s (3.4) × tilt × sin(the angle). This offset is recomputed each frame and **does not build up**. Holding sideways gives a constant 3 m/s drift, not a turn.
4. Above 9.6 m/s (14.4 for a long jump) the forward speed loses an extra 9 m/s².

Result: a committed arc. You can shorten it, lengthen it a bit, and nudge it sideways, but you cannot U-turn in mid-air.

- **Ours:** the velocity direction rotates toward the stick at `air_turn_rate3d` 6 rad/s (344°/s, almost the ground turn rate), at 30 m/s². The facing snaps to the stick. Compared to SM64 that is very loose: a full mid-air U-turn takes about 0.5 s.
- For SM64 feel: rotate at about 1–1.5 rad/s at most for normal jumps, keep the facing fixed in the air, and add a bounded sideways drift.

### 3.4 Landing

| Landing | Lag | Notes |
|---|---|---|
| Single / freefall / side flip | 4 frames (0.13 s) | land animation; a jump during it chains to the double jump |
| Double | 4 frames | a jump during it gives the triple (speed permitting) |
| Triple | 4 frames | no chain (a jump is ignored); celebratory anim if the stick is idle |
| Backflip | 4 frames | jump → another backflip only while crouch is still held |
| Long jump | 6 frames (0.2 s) | jump → another long jump only while crouch is still held |
| Ground pound | ~0.5 s stationary land | |
| Dive | belly slide | |

- **Speed during landing:**
  - With the stick held: the speed is multiplied by 0.98 per frame (gentle).
  - Without the stick and fast (≥ 4.8 m/s): braking at 36 m/s².
  - Otherwise: stopped.
- **When the lag ends:** to walking (stick held) or to a short "land stop" pose, then idle.
- **Fall damage:** landing faster than −16.5 m/s after falling more than 11.5 m (hero 12.9 m) hurts. Falls of more than 30 m hurt a lot and knock Mario down.
- **Ours:** `_land` goes straight to GROUND with no lag and no landing state, so the animation has nothing to show. Add a LAND state (§6).

---

## 4. Walls, ledges, hanging

### 4.1 How walls resolve (all states)
- Surfaces are classified by their normal:
  - floor if the normal's Y > 0.01;
  - ceiling if Y < −0.01;
  - otherwise a wall. Walls are effectively vertical.
- **In the air:**
  - Walls are probed at 0.30 m (radius 0.5 m) and 1.50 m (radius 0.5 m) above the feet. That covers the whole body.
  - A probe overlapping a wall plane is pushed straight out along the wall normal, horizontally only.
  - Several quarter-steps per frame keep fast motion from tunnelling.
- **What a wall does to an airborne Mario** depends on the angle between his facing and the wall:
  - **Glancing** (wall normal more than 45° from straight against his facing): push-out only. He slides along the wall with no state change.
  - **Head-on (within ±45°), forward speed > 4.8 m/s:** a **wall hit**. This opens the wall-kick window (§4.2). If he does not kick, he **bonks**:
    - a soft bonk (bounced back at −2.4 m/s), or a hard knockback if he hit faster than 11.4 m/s;
    - the upward speed is zeroed.
  - **Head-on but slower than 4.8 m/s:** the forward speed is zeroed. He drops straight down the wall face with no bonk.
- Dives and ground pounds that hit a wall always bonk.
- **Ceilings:** any ceiling within 1.6 m above the feet stops upward motion (vy = 0). There is no head bonk state.

### 4.2 Wall kick
- **Window:**
  - Jump pressed within **1–2 frames (≈ 0.03–0.07 s)** of the head-on wall hit ("first-frame" kick);
  - or within **5 frames (0.17 s)** after the bonk starts.
- **Result:** the facing flips 180°, vy is 18.6 m/s, and the forward speed is at least 7.2 m/s, away from the wall.
- SM64 has **no wall slide**. Mario sticks to nothing. Our WALL_SLIDE (slow slide, kick at any time) is closer to Sunshine/Odyssey. It is far more forgiving, which is good for keyboard players, so keep it.
- The SM64 rules worth copying:
  - kicks only from a head-on approach (within ±45°);
  - a minimum approach speed (4.8 m/s);
  - a guaranteed launch speed away from the wall.

### 4.3 Ledge grab (from the air)
- **Conditions:**
  - only while falling (vy ≤ 0);
  - only in jump, double jump, freefall, side flip, wall kick and long jump. **Not** in the triple jump, backflip, dive or ground pound.
- **Detection:**
  - The **lower** wall probe (0.30 m above the feet) touches a wall, but the **upper** probe (1.50 m) touches nothing. So the wall's top edge is between Mario's knees and head.
  - The wall push-out pushed him *against* his horizontal velocity, so he is moving into it.
  - A floor is found 0.6 m into the wall, searching down from 1.6 m above the feet. That floor must be **more than 1.0 m above the feet**.
  - Hero version: the top must be 1.1–1.8 m above the feet. Compare ours: 0.7–1.4 m above the body centre, which is 1.55–2.25 m above the feet. Ours catches higher ledges, which is more generous, and is fine.
- **On grab:**
  - Mario's logical position is set **onto the ledge top**, at the floor height.
  - The facing points into the wall.
  - The hanging look is entirely the animation's offset: the body hangs below the root.
  - There is no physics while hanging.
- **While hanging:**
  - Floor under the ledge steeper than 25° → let go.
  - Crouch, or the floor vanishing → let go: moved 0.6 m back and up to 1 m down, into a soft fall.
  - Jump (with 1.6 m headroom) → **fast climb-up**.
  - After **10 frames (0.33 s)**, stick toward the wall → **slow climb-up**; stick away → let go.
  - If the ground behind is within 1 m, he auto fast-climbs (it is just a step).
- **Climb-up:**
  - The fast and slow climbs are fully **animation-driven**: the root stays on the ledge top and the animation plays the pull-up.
  - At the animation's end he becomes idle on top, nudged 0.14 m forward.
  - The slow climb can be cancelled into normal movement in its last third.
- SM64 has **no shimmy along ledges**. Hand-over-hand shimmy exists only on "hangable" ceilings (a separate hanging action). Our shimmy is an addition, and fine.

**Takeaway for our implementation:**
- SM64 never moves a collision body through a ledge corner. The logical position jumps to the top on the grab, and the animation covers the visual.
- We instead keep the capsule hanging below and, during PULL_UP, **disable collision** and lerp the position (platformer_motor.gd:520-541). That works, but it creates the PULL_UP bugs in §5.3.
- The SM64 way also simplifies camera framing.

---

## 5. Animation coupling

### 5.1 How SM64 guarantees no stale pose
1. **The action owns the animation.** Every action handler requests its animation **every frame**. The request is idempotent: it restarts the clip only when the clip *changes*.
   - The current action and the visible clip can never disagree for more than the frame of a transition.
   - No separate system "infers" the pose from velocity or floor contact.
2. **Locomotion picks a clip by speed, with hysteresis, and drives the playback rate from speed.** The speed used is max(stick magnitude, forward speed), so pushing into a wall still animates.

   | Clip | Used while | Leaves when |
   |---|---|---|
   | start tiptoe → tiptoe | speed < 2.4 m/s (hero 2.7) | > 2.4 m/s → walk |
   | walk | 1.5 – 6.6 m/s (hero 1.7 – 7.4) | < 1.5 → tiptoe; > 6.6 → run |
   | run | > 5.4 m/s (hero 6.1) | < 5.4 → walk |

   - Playback rate = speed / (1.2 m/s) × the base rate, so feet stay planted at every speed.
   - The gap between 5.4 and 6.6 is the hysteresis that prevents flicker.
3. **Every non-walking ground action has its own clip:** brake skid, turnaround parts 1 and 2, decelerating (the walk clip slowing down), push, side-step, crouch, crouch slide, butt slide, stomach slide.
4. **Every air action has its own clip, and some pick a rise or fall variant from the sign of vy.** Freefall chooses between "general fall", "fall from slide" and so on by how it was entered.
5. **Every landing is its own short action with its own clip** (§3.4). A landing can never be skipped visually.
6. **Hits are actions.** Knockback (ground or air, forward or back, soft or hard), bonks, burns and stuns each have clips. When one finishes it returns to idle, walking or freefall, so the hit state never leaks into the next move.
7. **Body tilt** (§2.1) is an additive torso rotation computed from the speed and the turn rate. Like the lean on slides, it is reset to zero whenever the clip is not walk or run.

### 5.2 Ratchet & Clank
- The public RC1 decompilation (Lombyte, and OpenRAC rac1-decomp, which adapts it) has hero state machine code partly matched to C:
  - `hero_update_movement`
  - `hero_update_transitions`
  - `set_hero_animation`
  - `hero_handle_jump_press`
- Much of it is raw field offsets and unnamed constants, so only high-level behaviour could be read reliably:
  - **One explicit state per move**, including a dedicated **HURT** state, **STOP** (a stop-from-run state, like SM64's decelerate/brake), **LAND**, and "wait for the animation, then idle" recovery states.
  - The moves include run, stop, crouch, fall, jump, land, run-jump, high jump (crouch + jump), double jump, pack long jump, wrench combo/slam, ledge hang with left/right shimmy and a ledge jump, grind, swim, and idle fidgets.
  - So R&C follows the same rule as SM64: animation is a function of the state, and taking damage is a state.
- **Ledge detection, as read from the RC1 probe:**
  - Step forward from the hero in 4 short increments, looking down for a **flat top (within 20° of horizontal)**.
  - The top must be no more than ~1.5 units above the hero and at least ~1.8 units above the ground he is on.
  - Probe for the wall under it at **5 heights**.
  - The hero must face the wall within ~65° for the probe, then within ~30° to accept.
  - Certain surface materials are excluded.
  - Units are the game's own; we did not verify their metric scale.
- **Publicly documented feel** (from the official control lists and common knowledge of the series):
  - very snappy, low-inertia running with near-instant direction changes;
  - a modest jump plus a double jump;
  - crouch + jump = high jump; run + crouch + jump = long jump;
  - wrench slam on landing;
  - strafing (in later games) while shooting, with the facing locked to the aim.
- No further tuning numbers could be confirmed, so none are given here.

**Recommendation:** Mario 64's model (facing-led ground motion, committed air arcs, landing states) is the better match for the "platformer feel" request. Keep R&C's responsiveness only where it helps combat: our instant start and snappy stops while attacking.

### 5.3 Why our hero gets stuck in a pose and slides: likely causes
Ranked by likely impact. File:line references are to the current tree.

1. **The motor is frozen while the body keeps moving, and the animator keeps drawing the frozen motor state.**
   - Where: player.gd:341-354 runs `motor.step` only when the hero is not dodging, stunned or attacking.
   - What the animator does: `_apply_pose` (art_animator.gd:438-479) reads `motor.state` and `motor.state_time` every frame, including while the motor is not stepped.
   - **Getting hit:** `_on_hit_received` (player.gd:648-660) sets the knockback velocity and the stun but **never resets the motor**.
     - Hit mid triple jump, backflip or side flip: `state_time` stops advancing, so the procedural flip **freezes mid-rotation** (possibly upside-down) while the knockback slides the body for the whole hitstun.
     - Hit during SLIDE: the 35° lean plus squash stay on while the body is knocked back.
     - Hit during HANG or CLIMB: gravity and knockback move the body. When the stun ends, `_step_hang` / `_step_climb` zero the velocity, so the hero **hangs frozen in mid-air** at the wrong spot.
     - Hit during PULL_UP: the collision disabled at platformer_motor.gd:520-521 is never re-enabled, because only `_step_pull_up` re-enables it. The hero can fall through the floor.
   - **Attacking:** attacks call `motor.reset()` on start (player.gd:644), which hides this for attacks but not for hits.
2. **The air pose comes from `is_on_floor()`, not the motor state.**
   - Where: art_animator.gd:527-531.
   - Whenever the hero is not on the floor for more than 0.08 s, the tree blends fully into the looping `fall` clip. That includes HANG, CLIMB, CLIMB_LEAP, WALL_SLIDE and PULL_UP (collision disabled, so never on the floor).
   - So hanging, climbing and pulling up all show the fall loop, with only a few degrees of procedural tilt on top.
3. **Locomotion is blended from raw velocity in every state.**
   - Where: art_animator.gd:517-524.
   - SLIDE (platformer_motor.gd:225-232, 6–11 m/s) and SKID (218-224) play the **run cycle** under a lean, so the legs run while the body slides.
   - CROUCH plays the walk cycle squashed.
   - CLIMB moving sideways at 2 m/s plays a walk cycle against the wall.
4. **Teleport-style motion with zero velocity.** The animator sees speed 0 and plays idle while the body glides. Cases:
   - ledge shimmy writes `global_position` directly (platformer_motor.gd:507);
   - the pull-up lerps the position (533-537);
   - the climb snaps to the wall every frame (595-597);
   - the ledge grab snaps up to about 1 m (464).
5. **The facing snaps to the stick while the velocity lags behind.**
   - Where: player.gd:322-323 and 437-442. This runs in GROUND, SLIDE, CROUCH and most AIR kinds, because only some states lock the facing (platformer_motor.gd:127-129).
   - In SLIDE the velocity turns at 1.5 rad/s, but the model turns instantly to the stick, so it slides sideways.
   - In the air the model spins to the stick while momentum carries it the old way.
   - This is the "moonwalk" that SM64's facing-led model makes impossible (§1.3).
6. **No state exists for "not on floor but on a surface".**
   - POUND_FALL (platformer_motor.gd:172-176) exits only when `on_floor` is true.
   - Landing on a face steeper than `floor_max_angle` (50°, main.gd:140), or on a non-floor body, gives `is_on_floor()` false. The velocity (0, −26, 0) is turned by `move_and_slide` into **sliding down the slope in the pound pose**, indefinitely.
   - AIR (186-197) has the same problem: on a steep face the hero slides down in the fall loop forever.
7. **No landing, decelerate or brake states.**
   - `_land` (325-336) goes straight to GROUND.
   - With no stick, GROUND stops at 90 m/s² (platformer_motor.gd:248).
   - With the stick, the speed jumps to `start_speed3d`.
   - The smoothed blend (art_animator.gd:520) then lags about 0.1 s behind these instant speed changes. The clips briefly disagree with the motion: a short "slide to a stop in a running pose".
8. **CLIMB can idle with no valid wall.**
   - Where: platformer_motor.gd:630-641.
   - If no climb hit is found in any direction, the velocity becomes 0 but the state stays CLIMB. There is no exit except a jump or crouch, so the hero floats in the climb pose.
   - This happens after a moving or disabled wall, or after a snap that misses.
9. **Locomotion playback is capped at 1.8×.**
   - Where: art_animator.gd:524.
   - With RUN_REF 5.5 m/s, the feet match up to 9.9 m/s. The boost (11 m/s), the long-jump landing (up to 11) and the dash exit skate visibly.
10. **The takeoff clip plays on every launch.**
    - Where: the `jumped` signal → `act(&"jump", 0.22 …)` (art_animator.gd:330).
    - It plays as a full-body one-shot even for the backflip, side flip, wall kick and long jump, and fights the procedural flip for 0.22 s.

The rule that fixes 1–8 together is SM64's: **every motor state names its animation, the animator plays exactly that, and nothing outside the motor may move the body without the motor being in a state that represents it** (knockback, attack, dash).

---

## 6. Mapping table: SM64 concept → PlatformerMotor

Status: **Have** (present and comparable), **Partial** (present with a material difference), **Missing**.

| SM64 concept | Recommended change in our motor (numbers are hero-scaled) | Status |
|---|---|---|
| Squared stick → intended magnitude | Square the stick magnitude before scaling the target speed (or a 1.5 power): half tilt ≈ quarter speed | Missing (linear) |
| Facing-led ground motion | On GROUND, keep a scalar `forward_speed` and a motor-owned facing. Turn the facing toward the stick at ~6 rad/s (340°/s). Velocity = facing × speed. Stop `player._update_facing` from writing `_facing_3d` while the motor is active; the motor writes it | Missing (facing snaps; velocity rotates separately) |
| Accel curve | Instant 2.7 m/s start, then accel = 11 − 0.8·v m/s² up to the target (≈ 1.5 s to 10.8 m/s). Our boost can stay as the top-end extension | Partial (accel 70 constant) |
| Top speeds | Run 10.8 m/s (or keep 8.5 → 11 boost); ground cap 16 m/s | Partial |
| Decelerate (no stick, < 5.4 m/s) | New DECEL state: −10 m/s², walk cycle slowing, then IDLE | Missing (90 m/s² instant stop) |
| Brake / skid (no stick, ≥ 5.4 m/s) | New BRAKE state: −40 m/s², skid anim and dust; jump → normal jump | Missing |
| Turnaround + side flip | SKID: trigger at stick > 100° from the facing and ≥ 5.4 m/s; brake at 40 m/s² instead of a fixed 0.18 s; exit along the new facing at 2.7 m/s; jump → SIDE_FLIP (vy 18.6–21, 2.7 m/s) | Have (angle 150°, 6 m/s, fixed time; fine to keep) |
| Pushing / side-stepping on walls | On GROUND hitting a wall: clamp the speed to 2 m/s and set an anim flag `push` (head-on) or `sidestep` (glancing) | Missing |
| Step-up / snap-down | Step ≈ 0.34 m; snap 0.4–0.5 m | Partial (snap 0.35; no explicit step-up, so use ramp collision on stairs or add one) |
| Slow edge → climb down to hang | Walking < 3 m/s at a drop > 1.8 m → turn around into HANG | Missing (optional, nice for the open hub) |
| Slope classes | Tag floors with a class (metadata or physics material): default floors slide above 38°, "slide" floors above 20°, "grip" never. Add a SLOPE_SLIDE state (butt/belly) with acceleration ≈ 70 m/s² × sin(slope), multiplied by 0.92 per 1/30 s, stick steering, jump after 0.17 s | Missing |
| Steep-face fallback | Any frame on a surface steeper than `floor_max_angle` (`is_on_floor` false but `is_on_wall` with normal.y > 0.3): enter SLOPE_SLIDE, not AIR or POUND_FALL. Push off above ~73° | Missing (cause #6) |
| Landing states | New LAND state, 0.13 s (long jump 0.2 s, pound 0.4 s): speed × 0.98/frame with stick, brake without; jump chains; carries `jump_kind` for the anim | Missing |
| Chain window | `CHAIN_WINDOW` 0.15 → 0.25 s; triple gate 6.75 m/s **at the double-jump landing** (ours: `CHAIN_MIN_SPEED` 5) | Partial |
| Jump heights | Single 2.5 (+ running bonus 0.25·v to vy), double 3.8–5.1, triple 6.7, backflip 5.4, side flip 5.4, wall kick 5.4, long 2.5 m | Partial (2.3/2.9/3.8/3.6/3.2/2.6/1.0, no speed bonus). Ours are deliberately lower; keep them for tight 3D World stages, or raise them for the open hub |
| Forward-speed carry on jump | Single and double keep 80% of the forward speed; the triple too; long jump × 1.5 capped at 16 m/s | Partial (full carry; long jump +3 m/s clamped to 14–16) |
| Gravity / terminal | 40 m/s² both ways (or keep the asymmetric fall at ≤ 50); terminal 25 m/s | Partial (35.5 / 63; terminal 36) |
| Jump cut | While rising faster than 6.75 m/s with jump released: vy × 0.25 per 1/30 s | Have (one-shot × 0.45; fine) |
| Air steering | Facing fixed in the air for SINGLE/DOUBLE/TRIPLE/FALL; forward speed ±15 m/s² along the facing; non-accumulating sideways drift ≤ 3.4 m/s; drag 3.5 m/s²; extra −10 m/s² above 10.8 m/s (16 for the long jump) | Partial (6 rad/s velocity turn; the facing follows the stick) |
| Air wall bonk | Head-on (±45°) wall at > 5.4 m/s without a kick → BONK (bounce back 2.7 m/s, vy = min(vy, 0)); > 12.8 m/s → AIR_KNOCKBACK | Missing |
| Wall kick | Keep WALL_SLIDE. Enter only from a head-on approach (±45°) at ≥ 5.4 m/s, or while pushing into the wall; kick = vy 18.6–21 m/s, ≥ 8.1 m/s away | Have (kick 7.5 m/s; no angle or speed gate) |
| Ledge grab | Only while falling; not from TRIPLE, BACKFLIP, pound or dive (SM64 does allow it from the long jump). Window: top 1.1–2.2 m above the feet. Optionally adopt SM64's "logical position on top, animation hangs below" so PULL_UP needs no collision toggling | Have (detection), Partial (rules) |
| Hang rules | Ignore the stick-to-climb for 0.33 s after the grab; jump = fast climb (~0.3 s); stick toward = slow climb (~0.9 s); stick away or crouch = drop (0.6 m back) | Partial (0.12 s guard, a single pull-up speed) |
| Ground pound | Spin 0.3–0.45 s with a 1.2 m rise, then fall from 17 m/s accelerating to terminal; LAND 0.4 s | Have (fixed 26 m/s, no rise) |
| Dive / rollout | Optional: attack in the air at > 9.5 m/s → DIVE (+5 m/s), belly-slide landing, jump → rollout | Missing (combat uses attack; low priority) |
| Damage is a state | New KNOCKBACK state (air/ground variants) entered from `_on_hit_received`. It owns the velocity decay, gravity, collision re-enable and anim, and exits to GROUND/AIR. Also exit HANG/CLIMB/PULL_UP on hit | Missing (cause #1) |
| Attack / dash as states | Either step the motor with a pass-through ATTACK/DASH state, or `reset()` on dash start and end and on attack end, so `state_time` and the facing never freeze | Partial (reset on start only) |
| Animation from state | ArtAnimator reads one `motor.anim_state()` (state + jump kind + rise/fall + locomotion speed) instead of `is_on_floor()` and raw velocity. Locomotion blend only in GROUND/DECEL; dedicated clips or poses for every other state; the climb and hang anim parameter driven by motor progress, not velocity | Missing (causes #2–#4) |
| Walk/run clip hysteresis + rate | Walk 1.7–7.4 m/s, run above 6.1 m/s (hysteresis); rate = speed / clip reference with no 1.8× cap (or cap ≥ 3×) | Partial (BlendSpace1D, cap 1.8×) |
| Run lean / turn roll | Additive pitch from speed (≤ 30°) and roll from the turn rate × speed (≤ 30°), eased ~170°/s; zero outside GROUND | Missing |

---

## 7. Level geometry for an open, non-linear 3D hub

SM64 courses are open bowls: one spawn point, many goals reachable in any order, the boundaries made of terrain, water and pits rather than invisible walls. To build that safely for our motor:

### 7.1 Collision rules
- **Classify by normal, not by node.** Floor if the angle from up is < 38° for default floors (our `floor_max_angle` 50° is acceptable, but then treat 38–50° as "slides if the floor is tagged slippery"). Wall if 80–100°. Avoid authoring 50–80° faces unless they are deliberate slide chutes: they are where the hero is "not on floor, not climbable" and slides in a stuck pose.
- **Walls are vertical; ledges are flat.** A ledge grab needs a vertical face under a flat top (within ~20°, per both games). Bevels and rounded lips break the grab and the wall kick. Put 0.05–0.1 m chamfers on visuals only.
- **Collision is simpler than the visuals.** Use box/convex collision with clean top edges. No trimesh on walkable rocks with micro-bumps, which flicker `is_on_floor` (and the air blend).
- **Step and headroom budget (hero scale):**
  - steps ≤ 0.34 m (stairs 0.2–0.3 m);
  - crawl gaps ≥ 1.1 m;
  - walk gaps ≥ 1.9 m;
  - ledge-grabbable lips 1.1–2.2 m above where you jump from.
- **Jump metrics to design with** (our current tuning; recompute after retuning):
  - single jump at a run ≈ 5.4 m flat gap;
  - long jump ≈ 9 m;
  - triple-jump apex 3.8 m;
  - wall-kick chain shafts 3–4 m wide;
  - keep "basic jumps only" completion, as the platformer design already says.
- **Surface tags:** grip (never slides: stairs, bridges), default, slide (chutes and ice), climbable (existing `climbable` group), hazard. Store them as metadata or a physics-material name the motor reads from the floor collider.

### 7.2 Bounds without invisible walls
- **Soft boundaries first:**
  - rising terrain (cliffs taller than any jump plus grab, i.e. > 7 m sheer, non-climbable);
  - deep water or void with clear visual fog;
  - long gentle slopes back toward the play space.
- **A death plane under every open edge.** It is a kill volume at a fixed Y. On entry:
  - fade out;
  - deal fall damage (blood cost);
  - respawn at the **last safe ground position**: a point recorded every ~0.5 s while on a flat (≤ 20°), non-hazard, non-moving floor, at least 1 m from an edge.
  - SM64 itself takes a life on pits. For a roguelike, damage + respawn keeps the run going.
- **Invisible walls only where the camera or engine requires them** (out-of-map skybox gaps), and then **tall** (> jump apex + 2 m) so the hero never lands on top or ledge-grabs them. Tag them `no_grab`, `no_wall_kick`.
- **Out-of-bounds failsafe:** if the hero is below the death plane or more than N m from the level's bounding box, respawn at the last safe position. This protects against tunnelling.

### 7.3 Camera for open courses
- **Free orbit**, with the existing third-person spring arm:
  - auto-swing behind the direction of travel only after ~1 s without camera input, and only when running (not on a ledge or climbing);
  - collision pulls in toward the player and never through ceilings.
- **Fixed or framed camera zones** (SM64 uses area-specific modes) for tight interiors, wall-kick shafts and climb walls: an `Area3D` that sets a preferred yaw/pitch/distance while the hero is inside.
- **Stick input stays camera-relative**, but lock the camera basis used for movement while the stick is held through a camera swing. SM64 recomputes from the camera each frame, but its camera turns slowly. A fast-swinging camera plus instant re-mapping makes the hero curve unexpectedly.
- Raise the pitch and pull back over pits and when falling for more than 0.5 s, so the landing spot is visible.

### 7.4 Course layout pattern (SM64 style)
- A central "hub" bowl visible from the spawn, with 5–7 goals each on a different traversal theme (climb tower, wall-kick shaft, slide chute, moving platforms, floating islands). Most goals are visible from the hub (a landmark, a lit reliquary).
- **Several routes per goal:** the basic-jump route, plus moveset shortcuts (long jump across, triple jump up, wall-kick shortcut).
- **Goals reset or persist per visit** (SM64 picks a "mission" that changes small things). For us, the room's objective picks which goal is active, so rooms stay replayable.
- Keep enemies off ledge tops and wall-kick landing spots: a hit there is the commonest frustration.

---

## 8. Suggested order of work

1. **Animation and motor contract** (fixes the stuck pose): make damage a motor state and reset or end states on hit; the animator reads only the motor; dedicated poses for hang, climb, pull-up and slide; position-driven states feed a progress parameter.
2. **Facing-led ground motion** + DECEL/BRAKE/LAND states + squared stick.
3. **Air steering** with a fixed facing + bonk.
4. **Slope classes** + SLOPE_SLIDE + the steep-face fallback.
5. **Tuning pass** with the tables above, in the movement playground; then the level kit rules in §7.
