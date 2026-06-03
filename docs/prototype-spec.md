# Prototype Spec

## Core User Flow

1. User selects `Iron Session`.
2. App shows phone placement instructions.
3. User stands at address for 2 seconds.
4. App records motion data.
5. User hits 3 to 5 shots.
6. App segments each swing and returns likely faults.

## Data To Capture

From `Core Motion`:

- timestamp
- user acceleration x/y/z
- gravity x/y/z
- rotation rate x/y/z
- attitude roll/pitch/yaw or quaternion

Optional raw streams:

- accelerometer x/y/z
- gyroscope x/y/z

## Data Model

Each session should store:

- session id
- handedness
- club category
- mount position
- phone orientation
- calibration window
- swings

Each swing should store:

- swing id
- start timestamp
- end timestamp
- peak rotation rate
- lateral motion proxy
- rotation range proxy
- classification result
- confidence score

## Initial Classification Approach

Use heuristic thresholds before ML.

### Sway

Flag excessive lateral movement during takeaway and backswing relative to address baseline.

### Slide

Flag excessive lateral movement through downswing and impact without enough rotational recovery.

### Insufficient Rotation

Flag low rotational range or low peak rotational velocity compared with a benchmark band.

### Posture Loss

Experimental only. Infer from orientation change relative to address posture. Do not treat as production-ready in the first prototype.

## Calibration Requirements

The app should capture:

- stillness at address
- baseline gravity vector
- baseline device orientation
- baseline noise level

If the phone is moving too much during calibration, force a retry.

## Data Collection Plan

Target:

- 5 to 10 golfers
- 50 to 100 total swings

For each golfer:

- 5 normal swings
- 3 intentional sway swings
- 3 intentional slide swings
- 3 intentional low-rotation swings

Record video alongside sensor capture when possible so labels can be reviewed later.

## Success Criteria

- setup under 30 seconds
- repeatable signal shape swing to swing
- sway and slide detect better than chance
- output feels believable after one session

## Biggest Risks

- loose pocket noise
- inconsistent phone orientation
- handedness affecting signal interpretation
- overpromising posture or early-extension detection
