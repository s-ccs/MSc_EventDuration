# **M.Sc. Thesis: Investigating the effect of overlap and event durations on the neural response**
**Author**: *Martin Geiger*
**Supervisors**: *Jun.-Prof. Dr. Benedikt Ehinger, Prof. Dr. Nadja Schott, René Skukies, M.Phil.*
**Year**: *2022*
## Project Description
Neural responses intermingled in the electroencephalogram (EEG) must be distinguished to study the dynamics of sensory encoding, decision-making, and motor action that drive human behaviour. Two data-analytic challenges complicate the accurate estimation of event-related potentials (ERPs) during complex experimental paradigms and naturalistic situations: 

1) Overlap of neural responses due to close temporal proximity of adjacent events. 

2) Varying event durations, e.g. due to natural variation in response time (RT) or experimentally varying stimulus durations.

In this study, I carried out an active visual oddball experiment (and an active visual distractor task which I couldn’t investigate due to time contraints) with 38 participants and analysed the effects of overlap and varying event durations on neural responses. The analysis included the comparison of ERP estimates obtained from three regression-based models:

i) Mass univariate model for comparison with traditional averaging approach. (nb_Oddball_MU.jl)

ii) Deconvolution model for overlap correction. (nb_Oddball_DC.jl)

iii)  Generalised additive model (GAM) where RT, modelled via spline regression, is added as an additional predictor to ii). (nb_Oddball_GAM.jl)

## Folder Structure 
```
│projectdir          <- Project's main folder
|
├── exp              <- Matlab scripts for stimulus presentation (via Psychtoolbox-3) and data acquisition
│   │                   during 2 experiments: P300 and stimDur
│   ├── functions    <- Various functions required for drawing instructions, 
│   │                   sending event triggers, saving , etc.
│   ├── setup        <- Setup functions
|
├── lib              <- Infos regarding the images presented during stimDur experiment
│
├── report           <- Thesis and talks
│   ├── talks        <- PDFs of the intro talk & final presentation
│   ├── thesis       <- PDF of the final thesis
│
├── src              <- Source code for this project. Contains scripts for conversion of 
│   │                   raw data to BIDS format, preprocessing, functions, and Julia notebooks
│   ├── functions    <- Functions for loading, syncing, and dejittering data in Julia, 
│   │                   as well as for ICA and AMICA in Matlab
│   ├── nb_julia     <- Julia notebooks for timing test, data analysis, plotting, etc.
│
├── README.md        <- Top-level README
```
