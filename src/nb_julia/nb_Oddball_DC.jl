### A Pluto.jl notebook ###
# v0.19.14

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 16b920a4-08d5-11ed-3512-8b6269563ef3
begin
	using CSV
	using XDF
	using DataFrames
	using DataFramesMeta
	using Unfold
	using UnfoldMakie
	using CairoMakie
	using PlutoUI
	using AlgebraOfGraphics
	using Statistics
	using StatsBase
	using StatsModels
	using MixedModels
	import DSP.conv
	using DSP
	using Printf
	using PyMNE
	using PyCall
	using Bootstrap
	using HypothesisTests
	using TopoPlots
	using Colors
end

# ╔═╡ 0f65f18b-cfc9-4ad5-97a8-eb4dc634fb31
md"# Linear deconvolution model for overlap correction
#### Oddball task - P300
###### 2022-MSc Thesis by Martin Geiger"

# ╔═╡ 18d9b04e-0d71-4d09-8145-50bfcd125cd2
md"### 0.1 Import Packages"

# ╔═╡ d22822f9-6f8d-401f-b7c4-a00b4520a4bb
TableOfContents()

# ╔═╡ 35004d67-c8cb-417d-9724-3dca1fd6990c
md"### 0.2 Import Data & Events"

# ╔═╡ e35af0f8-2e06-46bf-b861-4a1f01f655f9
function loadSub(sub,task)
	# Load events
	events = CSV.read(@sprintf("/home/geiger/2022-MSc_EventDuration/code/analysis/results/relevantEvents/%s_finalEvents.csv",sub),DataFrame, delim=",")

	# Load raw data
	#raw = PyMNE.io.read_raw_eeglab("/store/data/MSc_EventDuration/sub-"*sub*"/ses-001/eeg/sub-"*sub*"_ses-001_task-"*task*"_run-001_eeg.set")
	
	# Load preprocessed data
	raw = PyMNE.io.read_raw_eeglab("/store/data/MSc_EventDuration/derivatives/preprocessed_Oddball/sub-"*sub*"/eeg/sub-"*sub*"_ses-001_task-"*task*"_run-001_eeg.set",verbose="ERROR")

	# Get sampling frequency
	sfreq = raw.info["sfreq"]

	# Re-reference
	raw = raw.set_eeg_reference(ref_channels=["P7","P8"])

	# Set correct channel types for EOG channels
	raw.set_channel_types(Dict("HEOGR"=>"eog","HEOGL"=>"eog","VEOGU"=>"eog","VEOGL"=>"eog"))
	
	# Add subject to DataFrame to easily subset when not looking at all subjects
	events[!,:subject] .= parse.(Int64,sub)
	
	return events,sfreq,raw
end;

# ╔═╡ edf18493-eb61-4f51-8fb1-528f826f5dfe
begin
	subList = ["005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "019" "020" "021" "022" "024" "025" "026" "028" "029" "030" "031" "032" "033" "034" "035" "036" "037" "038" "039" "040" "041"]
	task = "Oddball"
	chIx = ["Pz"]
end;

# ╔═╡ 75764ab2-cf18-4db1-9b93-a09a077679fa
begin
	eventsList = Array{DataFrame}(undef,length(subList))
	sfreq = []
	EEG_raw = []

for (ix, sub) in enumerate(subList)
	events,sfreq,raw = loadSub(sub,task)

	eventsList[ix] = events
	EEG_raw = [EEG_raw;raw]
end
end;

# ╔═╡ c5d9548f-8f56-411b-ab9c-afcef6e93590
md"# 1. Model"

# ╔═╡ f96bd399-346a-4152-a0c3-cfe99d62e472
md"""
Coding Scheme: $(@bind CodingScheme html"<select><option value='Dummy'>Dummy</option><option value='Treatment'>Treatment</option></select>")
"""

# ╔═╡ 71ec0643-6513-4d38-b927-7b15833b1f14
md"### 1.1 Specify formulas and basisfunctions"

# ╔═╡ f8e06052-68f3-4902-b81a-fd2bd1569c89
if CodingScheme == "Dummy"
	design_lm = Dict(
	"stimulus"=>(
		@formula(0~0+target+distractor),
		firbasis(τ=(-1,1),sfreq=sfreq,name="stimulus")),
	"response"=>(
		@formula(0~0+bp_target+bp_distractor),
		firbasis(τ=(-1,1),sfreq=sfreq,name="response")),
	);
# I didn't use treatment coding for analysis. The statistics (2) in this script also aren't adapted to work on it. But I wanted to confirm that the ERP plots (4.1,4.2) produce the results that I expected them to, i.e. Intercept = dummy coded targets, and Intercept+distractor = dummy coded distractor
elseif CodingScheme == "Treatment"
	design_lm = Dict(
	"stimulus"=>(
		@formula(0~1+distractor),
		firbasis(τ=(-1,1),sfreq=sfreq,name="stimulus")),
	"response"=>(
		@formula(0~1+bp_distractor),
		firbasis(τ=(-1,1),sfreq=sfreq,name="response")),
	);
end;

# ╔═╡ f2514060-fc56-41f2-adfb-c09a480b5fce
md"### 1.2 Fit linear model"

# ╔═╡ b265f60b-7b97-4247-ae05-cc273eddda09
begin
	lm = []
	resultsAll = DataFrame()

	for (ix, subject) in enumerate(subList)
		data = EEG_raw[ix].get_data().*1e6

		lmSub = fit(UnfoldModel,design_lm,eventsList[ix],data,eventcolumn="event_type")

		resOne = coeftable(lmSub)
		resOne.subject .= subject
		append!(resultsAll,resOne)
		append!(lm,[lmSub])
	end
end

# ╔═╡ 473035e0-010a-400b-81f6-543906f2f33a
md"# 2. Statistics"

# ╔═╡ 8cf3ce68-fb9e-45f0-b596-3f36ff57de11
begin
	channels = [1:31;33:53;55:56;58:63] # only EEG channels
	coi = 26 # Channel of interest
end;

# ╔═╡ 90fe4492-4d9f-4d28-b4cb-f90d465d2bc1
md"### 2.1 Find peaks"

# ╔═╡ e710c8c3-520e-464c-b350-f28f7d06c746
begin
	mean_amp_diff_stim = []
	mean_amp_diff_resp = []
	t_peakStim = []
	t_peakResp = []
	evalEstimatesStimAll = []
	evalEstimatesRespAll = []
	evalEstimates_target = []
	evalEstimates_distractor = []
	evalEstimates_bp_target = []
	evalEstimates_bp_distractor = []
	
for i in 1:size(channels,1)
	evalEstimatesStimChan = []
	evalEstimatesRespChan = []
	evalEstimates_targetChan = []
	evalEstimates_distractorChan = []
	evalEstimates_bp_targetChan = []
	evalEstimates_bp_distractorChan = []
for (ix, subject) in enumerate(subList)
	# Subset to channel
	coefChannelOfInterest = groupby(coeftable(lm[ix]),:channel)[channels[i]]
	
	# Grouped dataframe of events
	events = groupby(coefChannelOfInterest,:coefname);

	# P300 evaluation window stimuli: 300-600 ms
	evalWinStart_stim = findfirst(x -> x > 0.3, events[1].time)
	evalWinEnd_stim = findlast(x -> x < 0.6, events[1].time)
	
	# P300 evaluation window responses: -50-50 ms
	evalWinStart_resp = findfirst(x -> x > -0.05, events[1].time)
	evalWinEnd_resp = findlast(x -> x < 0.05, events[1].time)
	
	# Get estimates inside evaluation window for each event
	evalEstimatesTarget1 = events[(coefname = "target",)].estimate[evalWinStart_stim:evalWinEnd_stim]
	evalEstimatesDistractor1 = events[(coefname = "distractor",)].estimate[evalWinStart_stim:evalWinEnd_stim]
	evalEstimatesBPTarget1 = events[(coefname = "bp_target",)].estimate[evalWinStart_resp:evalWinEnd_resp]
	evalEstimatesBPDistractor1 = events[(coefname = "bp_distractor",)].estimate[evalWinStart_resp:evalWinEnd_resp]

	# Calculate full difference waves
	diffStim = events[(coefname = "target",)].estimate .- events[(coefname = "distractor",)].estimate
	diffResp = events[(coefname = "bp_target",)].estimate .- events[(coefname = "bp_distractor",)].estimate
	
	# Calculate difference waves inside evaluation window
	evalEstimatesStim = evalEstimatesTarget1 .- evalEstimatesDistractor1
	evalEstimatesResp = evalEstimatesBPTarget1 .- evalEstimatesBPDistractor1

	# Find peaks and amplitudes inside evaluation window
	peak_loc_stim,peak_amp_stim = PyMNE.preprocessing.peak_finder(evalEstimatesStim,extrema=1,verbose="ERROR")
	peak_loc_resp,peak_amp_resp = PyMNE.preprocessing.peak_finder(evalEstimatesResp,extrema=1,verbose="ERROR")

	# Find maximum amplitude if more than one peak is found
	if !isempty(peak_amp_stim) && !isempty(peak_amp_resp)
	amp_stim = maximum(peak_amp_stim)
	amp_resp = maximum(peak_amp_resp)
	end

	# Find time of highest peak
	t_peak_stim = events[1].time[evalWinStart_stim+peak_loc_stim[argmax(peak_amp_stim)]]
	t_peak_resp = events[1].time[evalWinStart_resp+peak_loc_resp[argmax(peak_amp_resp)]]

	# Get index of highest peak
	ixPeakStim = evalWinStart_stim+peak_loc_stim[argmax(peak_amp_stim)]
	ixPeakResp = evalWinStart_resp+peak_loc_resp[argmax(peak_amp_resp)]

	# Find index steps that correspond to 150 ms
	step = findlast(events[1].time .<= events[1].time[1]+0.15)-1
	
	# Winsorized mean of absolute peak and values +-150 ms around it
	mean_amp_diff_stim1 = mean(winsor(diffStim[ixPeakStim-step:ixPeakStim+step],prop=0.2))
	mean_amp_diff_resp1 = mean(winsor(diffResp[ixPeakResp-step:ixPeakResp+step],prop=0.2))
	mean_amp_target1 = mean(winsor(events[(coefname = "target",)].estimate[ixPeakStim-step:ixPeakStim+step],prop=0.2))
	mean_amp_distractor1 = mean(winsor(events[(coefname = "distractor",)].estimate[ixPeakStim-step:ixPeakStim+step],prop=0.2))
	mean_amp_bp_target1 = mean(winsor(events[(coefname = "bp_target",)].estimate[ixPeakResp-step:ixPeakResp+step],prop=0.2))
	mean_amp_bp_distractor1 = mean(winsor(events[(coefname = "bp_distractor",)].estimate[ixPeakResp-step:ixPeakResp+step],prop=0.2))

	# Vectors with difference in peak time for each event and subject
	if i == coi
	append!(t_peakStim,t_peak_stim)
	append!(t_peakResp,t_peak_resp)

	# Vectors with amplitude at peak time (mean +-150 ms) ...
	# ... to calculate bootstrap and CI's
	append!(mean_amp_diff_stim,mean_amp_diff_stim1)
	append!(mean_amp_diff_resp,mean_amp_diff_resp1)
	end
	# ... to plot topographies
	append!(evalEstimatesStimChan,[mean_amp_diff_stim1])
	append!(evalEstimatesRespChan,[mean_amp_diff_resp1])
	append!(evalEstimates_targetChan,[mean_amp_target1])
	append!(evalEstimates_distractorChan,[mean_amp_distractor1])
	append!(evalEstimates_bp_targetChan,[mean_amp_bp_target1])
	append!(evalEstimates_bp_distractorChan,[mean_amp_bp_distractor1])
end
	append!(evalEstimatesStimAll,[mean(evalEstimatesStimChan)])
	append!(evalEstimatesRespAll,[mean(evalEstimatesRespChan)])
	append!(evalEstimates_target,[mean(evalEstimates_targetChan)])
	append!(evalEstimates_distractor,[mean(evalEstimates_distractorChan)])
	append!(evalEstimates_bp_target,[mean(evalEstimates_bp_targetChan)])
	append!(evalEstimates_bp_distractor,[mean(evalEstimates_bp_distractorChan)])
end
	# P300 peak latency
	t_peak_stim = mean(winsor(t_peakStim,prop=0.2))
	t_peak_resp = mean(winsor(t_peakResp,prop=0.2))
end;

# ╔═╡ 06454fb3-dc98-4bb2-952b-673aaf79915e
md"### 2.2 Bootstrap"

# ╔═╡ 7c333ba8-60d6-4be1-ba71-7747eda58529
# Bootstrap
begin
bootstrapStim = bootstrap(x->mean(winsor(x,prop=0.2)),mean_amp_diff_stim,AntitheticSampling(10000))

bootstrapBP = bootstrap(x->mean(winsor(x,prop=0.2)),mean_amp_diff_resp,AntitheticSampling(10000))
end;

# ╔═╡ 5d14aefb-eb45-4545-a6d4-a33f59017619
md"### 2.3 Confidence intervals"

# ╔═╡ b22a312d-df68-4768-84ca-3079255c4ea0
# Confidence intervals
begin
confintStim = HypothesisTests.confint(bootstrapStim, BCaConfInt(0.95))
confintBP = HypothesisTests.confint(bootstrapBP, BCaConfInt(0.95))
end;

# ╔═╡ f50769a6-e30e-40f9-9e42-bfb49155b789
md"### 2.4 Results: P300 latency & amplitude"

# ╔═╡ d658b65b-2e51-4784-8541-18cd8bb7b233
# Results for statistics of P300 component
begin
	statsOCresults = DataFrame(Event_Type=["stimulus","response"],
		Peak_Latency = [t_peak_stim,t_peak_resp],
		Std_Peak_Latency = [std(t_peakStim),std(t_peakResp)],
		Peak_Amplitude = [confintStim[1][1],confintBP[1][1]],
		Confidence_Interval_95Percent = [(confintStim[1][2],confintStim[1][3]),(confintBP[1][2],confintBP[1][3])])
end

# ╔═╡ ca6a9d5a-dfd9-4e51-b540-f7cdfb0e376e
md"# 3. Grand average"

# ╔═╡ 25d3d8e1-6b21-46f0-858c-5b465b7d2a06
GA = @chain resultsAll begin
	@subset(:channel .== 26)
	@by([:basisname,:coefname,:time],:estimate=mean(:estimate))
end;

# ╔═╡ b85a894e-8fbc-4344-9ff6-3fc6662882b3
md"### 3.1 Baseline correction"

# ╔═╡ 40236ca2-4f3d-4055-876c-b803ffda22c7
begin
	# Define baseline interval
	bslInterval = [-0.2,0]
	
	GA_bsl = DataFrame()
	# Group by events
	lm_GA_basis = groupby(GA,:basisname)

	for i in 1:size(lm_GA_basis,1)
		# Group by coefname
		lm_GA_coef = groupby(lm_GA_basis[i],:coefname)
		for j in 1:size(lm_GA_coef,1)
			# Calculate mean of estimates within baseline interval
			mean_bsl = mean(lm_GA_coef[j].estimate[findfirst(lm_GA_coef[j].time .>= bslInterval[1]):findlast(lm_GA_coef[i].time .<= bslInterval[2])])
			# Subtract mean_bsl from all estimates
			bslCorrected = combine(lm_GA_coef[j], :estimate => estimate -> estimate .- mean_bsl)
			append!(GA_bsl,bslCorrected)
		end
	end
	GA.estimate = GA_bsl.estimate_function
end;

# ╔═╡ f3c4c9d9-cc08-4851-888a-851c104b5067
begin
	GAsubsets = groupby(GA,[:basisname,:coefname])
	keys(GAsubsets)
end;

# ╔═╡ 586838f2-b504-4cef-8183-4e043d286080
md"# 4. Visualize Results"

# ╔═╡ 9dd3f057-b6b0-4da3-abfe-30970b596110
md"""
Basis: $(@bind basis_select PlutoUI.Select(unique(GA.basisname)))
"""

# ╔═╡ 93564e62-7031-42c7-bca5-edff000e0835
AlgebraOfGraphics.data(@subset(GA,:basisname.==basis_select))*mapping(:time,:estimate,color=:coefname) *visual(Lines)|>plt->draw(plt,legend=(position=:right,))

# ╔═╡ b16029f8-c699-463c-8d4f-986daa0a7c75
md"### 4.1 Stimulus-locked rERPs"

# ╔═╡ 0b585aea-a3f4-4adf-b05f-1d37664accd2
let
if CodingScheme == "Dummy"
	targetEstimatesOC = GAsubsets[(basisname = "stimulus", coefname = "target")].estimate
	distractorEstimatesOC = GAsubsets[(basisname = "stimulus", coefname = "distractor")].estimate
elseif CodingScheme == "Treatment"
	targetEstimatesOC = GAsubsets[(basisname = "stimulus", coefname = "(Intercept)")].estimate
	distractorEstimatesOC = GAsubsets[(basisname = "stimulus", coefname = "distractor")].estimate .+ targetEstimatesOC
end
	time = GAsubsets[1].time.*1e3

	avg_stim_OC = Figure()
	#ax_decreaseImageHeight = Axis(avg_stim_OC[1,1]) # change image ratio for plots
	#ax_decreseImageWidth = Axis(avg_stim_OC[1,4])
	ax_avg_stim_OC = Axis(avg_stim_OC[2:35,1:3],
		#title="Linear Deconvolution",
		xlabel="Time after stimulus onset [s]",
		ylabel="ERP [µV]",
		topspinevisible = false,
		rightspinevisible = false,
		xgridvisible = false,
		ygridvisible = false,
		titlesize = 100,
		xlabelsize = 80,
		ylabelsize = 80,
		xticklabelsize = 65,
		yticklabelsize = 65)
	diff = band!(time,
		0,
		targetEstimatesOC.-distractorEstimatesOC,
		color="lightgrey")
	#peakEval = poly!(Rect(Point2f[
	#	((t_peak_stim-0.02).*1e3,-3.5),
	#	((t_peak_stim-0.02).*1e3,6),
	#	((t_peak_stim+0.02).*1e3,-3.5),
	#	((t_peak_stim+0.02).*1e3,6)]),
	#	color=RGB{Float64}(0.935013, 0.871795, 0.835493),
	#	strokecolor=:black,
	#	strokewidth=1)
	difference = lines!(time,
		targetEstimatesOC.-distractorEstimatesOC,
		linewidth = 10,
		color="darkgrey")
	targets = lines!(time,
		targetEstimatesOC,
		linewidth = 10,
		color="dodgerblue")
	distractors = lines!(time,
		distractorEstimatesOC,
		linewidth = 10,
		color="midnightblue")
	stimOnset = vlines!(0,color="black",linestyle=:dash,linewidth = 6)
	# Peak time of individual subject's difference waves
	#for (ix, subject) in enumerate(subList)
	#	vlines!(t_peakStim[ix].*1e3,color=:red)
	#end
	#axislegend(ax_avg_stim_OC,
	#	[targets,distractors,difference,peakEval],
	#	["Target","Distractor","Target - Distractor","Peak"],
	#	position=:rt,
	#	labelsize=45)
	xlims!(current_axis(),-200,1e3)
	ylims!(current_axis(),-3.5,6)
	ax_avg_stim_OC.xticks = -200:200:1e3
	ax_avg_stim_OC.yticks = -4:2:6

	# Save plot
	#CairoMakie.save("/home/geiger/2022-MSc_EventDuration/code/analysis/results/plots/UsedInThesis/OC_stim.png",avg_stim_OC,resolution=(1920,1080))
	CairoMakie.save("/home/geiger/2022-MSc_EventDuration/code/analysis/results/plots/a.png",avg_stim_OC,resolution=(1920,1080))
	
	current_figure()
end

# ╔═╡ 84b6804a-b5c5-4033-9d53-75f99a21ba52
md"### 4.2 Response-locked rERPs"

# ╔═╡ f6cc51ad-8ae9-469a-9f59-0fa3169fe59b
let
if CodingScheme == "Dummy"
	bp_targetEstimatesOC = GAsubsets[(basisname = "response", coefname = "bp_target")].estimate
	bp_distractorEstimatesOC = GAsubsets[(basisname = "response", coefname = "bp_distractor")].estimate
elseif CodingScheme == "Treatment"
	bp_targetEstimatesOC = GAsubsets[(basisname = "response", coefname = "(Intercept)")].estimate
	bp_distractorEstimatesOC = GAsubsets[(basisname = "response", coefname = "bp_distractor")].estimate .+ bp_targetEstimatesOC
end
	time = GAsubsets[1].time*1e3

	avg_resp_OC = Figure()
	#ax_decreaseImageHeight = Axis(avg_resp_OC[1,1])
	#ax_decreseImageWidth = Axis(avg_resp_OC[1,4])
	ax_avg_resp_OC = Axis(avg_resp_OC[2:35,1:3],
		#title="Linear Deconvolution",
		xlabel="Time after response [s]",
		ylabel="ERP [µV]",
		topspinevisible = false,
		rightspinevisible = false,
		xgridvisible = false,
		ygridvisible = false,
		titlesize = 100,
		xlabelsize = 80,
		ylabelsize = 80,
		xticklabelsize = 65,
		yticklabelsize = 65)
	diff = band!(time,
		0,
		bp_targetEstimatesOC.-bp_distractorEstimatesOC,
		color="lightgrey")
	#peakEval = poly!(Rect(Point2f[
	#	((t_peak_resp-0.02)*1e3,-2.7),
	#	((t_peak_resp-0.02)*1e3,5),
	#	((t_peak_resp+0.02)*1e3,-2.7),
	#	((t_peak_resp+0.02)*1e3,5)]),
	#	color=RGB{Float64}(0.935013, 0.871795, 0.835493),
	#	strokecolor=:black,
	#	strokewidth=1)
	difference = lines!(time,
		bp_targetEstimatesOC.-bp_distractorEstimatesOC,
		linewidth = 10,
		color="darkgrey")
	targets = lines!(time,
		bp_targetEstimatesOC,
		linewidth = 10,
		color="dodgerblue")
	distractors = lines!(time,
		bp_distractorEstimatesOC,
		linewidth = 10,
		color="midnightblue")
	stimOnset = vlines!(0,color="black",linestyle=:dash,linewidth = 6)
	# Peak time of individual subject's difference waves
	#for (ix, subject) in enumerate(subList)
	#	vlines!(t_peakResp[ix].*1e3,color=:red)
	#end
	#axislegend(ax_avg_resp_OC,
	#	[targets,distractors,difference,peakEval],
	#	["Target","Distractor","Target - Distractor","Peak"],
	#	position=:rt,
	#	labelsize = 60)
	xlims!(current_axis(),-200,1e3)
	ylims!(current_axis(),-2.7,5)
	ax_avg_resp_OC.xticks = -200:200:1e3
	ax_avg_resp_OC.yticks = -4:2:6

	# Save plot
	#CairoMakie.save("/home/geiger/2022-MSc_EventDuration/code/analysis/results/plots/UsedInThesis/OC_resp.png",avg_resp_OC,resolution=(1920,1080))
	CairoMakie.save("/home/geiger/2022-MSc_EventDuration/code/analysis/results/plots/a.png",avg_resp_OC,resolution=(1920,1080))

	current_figure()
end

# ╔═╡ 21e58f39-0709-4508-94dd-a79b1d15bc6f
md"### 4.3 Topoplots"

# ╔═╡ bbbf6573-f932-41a4-82b2-4c00f0576387
# Have to disable the next cell, bcs deepcopy doesn't seem to work on PyMNE objects. Otherwise the EOG channels would get dropped right after loading the data in 0.2. Simply activate to plot topographies.

# ╔═╡ de576896-bfa3-4c5d-910d-375dff2a43e6
md"""
Topography: $(@bind topography html"<select>
<option value='stimTarget'>Target</option>
<option value='stimDistractor'>Distractor</option>
<option value='respTarget'>BP Target</option>
<option value='respDistractor'>BP Distractor</option>
</select>")
"""

# ╔═╡ d66806f8-d57d-4f7e-9414-2f3971954912
begin
	if topography == "stimTarget"
		plot_topo = Float32.(evalEstimates_target)
		range = [-2.6734145065927994,4.513866579161419]
	elseif topography == "stimDistractor"
		plot_topo = Float32.(evalEstimates_distractor)
		range = [-2.6734145065927994,4.513866579161419]
	elseif topography == "respTarget"
		plot_topo = Float32.(evalEstimates_bp_target)
		range = [-2.205226035626102,2.509699459224624]
	elseif topography == "respDistractor"
		plot_topo = Float32.(evalEstimates_bp_distractor)
		range = [-2.205226035626102,2.509699459224624]
	end
end;

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
Bootstrap = "e28b5b4c-05e8-5b66-bc03-6f0c0a0a06e0"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
DSP = "717857b8-e6f2-59f4-9121-6e50c889abd2"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
DataFramesMeta = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
HypothesisTests = "09f84164-cd44-5f33-b23f-e6b0d136a0d5"
MixedModels = "ff71e718-51f3-5ec2-a782-8ffcbfa3c316"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
PyMNE = "6c5003b2-cbe8-491c-a0d1-70088e6a0fd6"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
StatsModels = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
TopoPlots = "2bdbdf9c-dbd8-403f-947b-1a4e0dd41a7a"
Unfold = "181c99d8-e21b-4ff3-b70b-c233eddec679"
UnfoldMakie = "69a5ce3b-64fb-4f22-ae69-36dd4416af2a"
XDF = "31bc19ec-0089-417f-990e-a2b5e7515868"

[compat]
AlgebraOfGraphics = "~0.6.11"
Bootstrap = "~2.3.3"
CSV = "~0.10.4"
CairoMakie = "~0.8.13"
Colors = "~0.12.8"
DSP = "~0.7.7"
DataFrames = "~1.3.4"
DataFramesMeta = "~0.12.0"
HypothesisTests = "~0.10.10"
MixedModels = "~4.7.1"
PlutoUI = "~0.7.39"
PyCall = "~1.94.1"
PyMNE = "~0.1.2"
StatsBase = "~0.33.21"
StatsModels = "~0.6.31"
TopoPlots = "~0.1.2"
Unfold = "~0.3.11"
UnfoldMakie = "~0.1.4"
XDF = "~0.2.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.0"
manifest_format = "2.0"
project_hash = "f7ca9cbfd9d30c4c19f1e84538ee6c1f5df2b9f6"

[[deps.AMD]]
deps = ["Libdl", "LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "fc66ffc5cff568936649445f58a55b81eaf9592c"
uuid = "14f7f29c-3bd6-536c-9a0b-7339e30b5a3e"
version = "0.4.0"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "69f7020bd72f069c219b5e8c236c1fa90d2cb409"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.2.1"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.AbstractTrees]]
git-tree-sha1 = "5c0b629df8a5566a06f5fef5100b53ea56e465a0"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.2"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[deps.AlgebraOfGraphics]]
deps = ["Colors", "Dates", "Dictionaries", "FileIO", "GLM", "GeoInterface", "GeometryBasics", "GridLayoutBase", "KernelDensity", "Loess", "Makie", "PlotUtils", "PooledArrays", "RelocatableFolders", "StatsBase", "StructArrays", "Tables"]
git-tree-sha1 = "1b99dfa6ccc27abc03ac2aee0433eb2e3c2d4d4d"
uuid = "cbdf2221-f076-402e-a563-3d30da359d67"
version = "0.6.11"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Arrow]]
deps = ["ArrowTypes", "BitIntegers", "CodecLz4", "CodecZstd", "DataAPI", "Dates", "Mmap", "PooledArrays", "SentinelArrays", "Tables", "TimeZones", "UUIDs"]
git-tree-sha1 = "4e7aa2021204bd9456ad3e87372237e84ee2c3c1"
uuid = "69666777-d1a9-59fb-9406-91d4454c9d45"
version = "2.3.0"

[[deps.ArrowTypes]]
deps = ["UUIDs"]
git-tree-sha1 = "a0633b6d6efabf3f76dacd6eb1b3ec6c42ab0552"
uuid = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
version = "1.2.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Automa]]
deps = ["Printf", "ScanByte", "TranscodingStreams"]
git-tree-sha1 = "d50976f217489ce799e366d9561d56a98a30d7fe"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "0.8.2"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[deps.BSplines]]
deps = ["LinearAlgebra", "OffsetArrays", "RecipesBase"]
git-tree-sha1 = "5b609325fcb8f5fc124351b9267183722965860d"
uuid = "488c2830-172b-11e9-1591-253b8a7df96d"
version = "0.3.3"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Printf", "Statistics"]
git-tree-sha1 = "90b73db83791c5f83155016dd1cc1f684d4e1361"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "0.4.3"

[[deps.BitIntegers]]
deps = ["Random"]
git-tree-sha1 = "5a814467bda636f3dde5c4ef83c30dd0a19928e0"
uuid = "c3b6d118-76ef-56ca-8cc7-ebb389d030a1"
version = "0.2.6"

[[deps.BlockDiagonals]]
deps = ["ChainRulesCore", "FillArrays", "FiniteDifferences", "LinearAlgebra"]
git-tree-sha1 = "350372f249eb57922c44f6a4e762d6bcb75ef92a"
uuid = "0a1fb500-61f7-11e9-3c65-f5ef3456f9f0"
version = "0.1.36"

[[deps.Bootstrap]]
deps = ["DataFrames", "Distributions", "Random", "Statistics", "StatsBase", "StatsModels"]
git-tree-sha1 = "fb4bdaa6c24fea362cc54965c3f645f7cfac659f"
uuid = "e28b5b4c-05e8-5b66-bc03-6f0c0a0a06e0"
version = "2.3.3"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "873fb188a4b9d76549b81465b1f75c82aaf59238"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.4"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "d0b3f8b4ad16cb0a2988c6788646a5e6a17b6b1b"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.0.5"

[[deps.CairoMakie]]
deps = ["Base64", "Cairo", "Colors", "FFTW", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "SHA"]
git-tree-sha1 = "387e0102f240244102814cf73fe9fbbad82b9e9e"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.8.13"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "5f5a975d996026a8dd877c35fe26a7b8179c02ba"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.6"

[[deps.Chain]]
git-tree-sha1 = "8c4920235f6c561e401dfe569beb8b924adad003"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.5.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "80ca332f6dcb2508adba68f22f551adb2d00a624"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.3"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[deps.CodecLz4]]
deps = ["Lz4_jll", "TranscodingStreams"]
git-tree-sha1 = "59fe0cb37784288d6b9f1baebddbf75457395d40"
uuid = "5ba52731-8f18-5e0d-9241-30f10d1ec561"
version = "0.4.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.CodecZstd]]
deps = ["CEnum", "TranscodingStreams", "Zstd_jll"]
git-tree-sha1 = "849470b337d0fa8449c21061de922386f32949d9"
uuid = "6b39b394-51ab-5f42-8807-6242bab2b4c2"
version = "0.7.2"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "1fd869cc3875b57347f7027521f561cf46d1fcd8"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.19.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "d08c20eef1f2cbc6e60fd3612ac4340b89fea322"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.9"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSolve]]
git-tree-sha1 = "332a332c97c7071600984b3c31d9067e1a4e6e25"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.1"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "9be8be1d8a6f44b96482c8af52238ea7987da3e3"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.45.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "6e47d11ea2776bc5627421d59cdcc1296c058071"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.7.0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "59d00b3139a9de4eb961057eabb65ac6522be954"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.4.0"

[[deps.Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DSP]]
deps = ["Compat", "FFTW", "IterTools", "LinearAlgebra", "Polynomials", "Random", "Reexport", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "4ba2a190a9d05a36e8c26182eb1ba06cd12c1051"
uuid = "717857b8-e6f2-59f4-9121-6e50c889abd2"
version = "0.7.7"

[[deps.DataAPI]]
git-tree-sha1 = "fb5f5316dd3fd4c5e7c30a24d50643b73e37cd40"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.10.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "daa21eb85147f72e41f6352a57fccea377e310a9"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.4"

[[deps.DataFramesMeta]]
deps = ["Chain", "DataFrames", "MacroTools", "OrderedCollections", "Reexport"]
git-tree-sha1 = "a70c340c1306febfd770a932218561b5e19cf0f6"
uuid = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
version = "0.12.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Delaunay]]
deps = ["LinearAlgebra", "PyCall", "Random", "SparseArrays", "SpecialFunctions", "Test"]
git-tree-sha1 = "9cc9c5bdf00057a9c4befa9f73a3bad4363439c8"
uuid = "07eb4e4e-0c6d-46ef-bc4e-83d5e5d860a9"
version = "1.2.0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "96dc5c5c8994be519ee3420953c931c55657a3f2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.24"

[[deps.Dierckx]]
deps = ["Dierckx_jll"]
git-tree-sha1 = "633c119fcfddf61fb4c75d77ce3ebab552a44723"
uuid = "39dd38d3-220a-591b-8e3c-4c3a8c710a94"
version = "0.5.2"

[[deps.Dierckx_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6596b96fe1caff3db36415eeb6e9d3b50bfe40ee"
uuid = "cd4c43a9-7502-52ba-aa6d-59fb2a88580b"
version = "0.1.0+0"

[[deps.DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "28d605d9a0ac17118fe2c5e9ce0fbb76c3ceb120"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.11.0"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "aafa0665e3db0d3d0890cdc8191ea03dc279b042"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.66"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[deps.Effects]]
deps = ["DataFrames", "ForwardDiff", "LinearAlgebra", "Statistics", "StatsBase", "StatsModels", "Tables"]
git-tree-sha1 = "3c8098ee42c3227d1b7d602a4386f69e11dfb48f"
uuid = "8f03c58b-bd97-4933-a826-f71b64d2cca2"
version = "0.1.6"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[deps.Extents]]
git-tree-sha1 = "5e1e4c53fa39afe63a7d356e30452249365fba99"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.1"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "90630efff0894f8142308e334473eba54c433549"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.5.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FastClosures]]
git-tree-sha1 = "acebe244d53ee1b461970f8910c235b259e772ef"
uuid = "9aa1b823-49e4-5ca5-8b0f-3971ec8bab6a"
version = "0.3.2"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "94f5101b96d2d968ace56f7f2db19d0a5f592e28"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.15.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "129b104185df66e408edd6625d480b7f9e9823a0"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.18"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "246621d23d1f43e3b9c368bf3b72b2331a27c286"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.2"

[[deps.FiniteDifferences]]
deps = ["ChainRulesCore", "LinearAlgebra", "Printf", "Random", "Richardson", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "0ee1275eb003b6fc7325cb14301665d1072abda1"
uuid = "26cc04aa-876d-5657-8c51-4c34ba976000"
version = "0.12.24"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "2f18915445b248731ec5db4e4a17e451020bf21e"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.30"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "cabd77ab6a6fdff49bfd24af2ebe76e6e018a2b4"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.0.0"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics"]
git-tree-sha1 = "b5c7fe9cea653443736d264b85466bad8c574f4a"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.9.9"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLM]]
deps = ["Distributions", "LinearAlgebra", "Printf", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "StatsModels"]
git-tree-sha1 = "039118892476c2bf045a43b88fcb75ed566000ff"
uuid = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
version = "1.8.0"

[[deps.GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "fb28b5dc239d0174d7297310ef7b84a11804dfab"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.0.1"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "a7a97895780dab1085a97769316aa348830dc991"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.3"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "53c7e69a6ffeb26bd594f5a1421b889e7219eeaa"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.9.0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.HypothesisTests]]
deps = ["Combinatorics", "Distributions", "LinearAlgebra", "Random", "Rmath", "Roots", "Statistics", "StatsBase"]
git-tree-sha1 = "10b23fc711999d34f6888ab6df4c510def193fd9"
uuid = "09f84164-cd44-5f33-b23f-e6b0d136a0d5"
version = "0.10.10"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "acf614720ef026d38400b3817614c45882d75500"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.4"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "342f789fd041a55166764c351da1710db97ce0e0"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.6"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "87f7662e03a649cffa2e05bf19c303e168732d3e"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.2+0"

[[deps.IncompleteLU]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "a22b92ffedeb499383720dfedcd473deb9608b62"
uuid = "40713840-3770-5561-ab4c-a76e7d0d7895"
version = "0.2.0"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "5cd07aab533df5170988219191dfad0519391428"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.3"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "d19f9edd8c34760dca2de2b503f969d8700ed288"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.4"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "64f138f9453a018c8f3562e7bae54edc059af249"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.14.4"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "076bb0da51a8c8d1229936a1af7bdfacd65037e1"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.2"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "b3364212fb5d870f724876ffcd34dd8ec6d98918"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.7"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IterativeSolvers]]
deps = ["LinearAlgebra", "Printf", "Random", "RecipesBase", "SparseArrays"]
git-tree-sha1 = "1169632f425f79429f245113b775a0e3d121457c"
uuid = "42fd0dbc-a981-5370-80f2-aaf504508153"
version = "0.9.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "StructTypes", "UUIDs"]
git-tree-sha1 = "fd6f0cae36f42525567108a42c1c674af2ac620d"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.9.5"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "a77b273f1ddec645d1b7c4fd5fb98c8f90ad10a5"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.1"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "9816b296736292a80b9a3200eb7fbb57aaa3917a"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.5"

[[deps.Krylov]]
deps = ["LinearAlgebra", "Printf", "SparseArrays"]
git-tree-sha1 = "a024280a69c49f51ba29d2deb66f07508f0b9b49"
uuid = "ba0b0d4f-ebba-5204-a429-3ac8c609bfb7"
version = "0.7.13"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LDLFactorizations]]
deps = ["AMD", "LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "736e01b9b2d443c4e3351aebe551b8a374ab9c05"
uuid = "40e66cde-538c-5869-a4ad-c39174c6795b"
version = "0.8.2"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LinearOperators]]
deps = ["FastClosures", "LDLFactorizations", "LinearAlgebra", "Printf", "SparseArrays", "TimerOutputs"]
git-tree-sha1 = "b404faa9b85e62c0eeec7a600d5b4316c58215ed"
uuid = "5c8ed15e-5a4c-59e4-a42b-c7e8811fb125"
version = "2.3.2"

[[deps.Loess]]
deps = ["Distances", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "46efcea75c890e5d820e670516dc156689851722"
uuid = "4345ca2d-374a-55d4-8d30-97f9976e7612"
version = "0.5.4"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "361c2b088575b07946508f135ac556751240091c"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.17"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Lz4_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "5d494bc6e85c4c9b626ee0cab05daa4085486ab1"
uuid = "5ced341a-0733-55b8-9ab6-a4889d929147"
version = "1.9.3+0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "e595b205efd49508358f7dc670a940c790204629"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.0.0+0"

[[deps.MLBase]]
deps = ["IterTools", "Random", "Reexport", "StatsBase"]
git-tree-sha1 = "3bd9fd4baf19dfc1edf344bc578da7f565da2e18"
uuid = "f0e99cf1-93fa-52ec-9ecc-5026115318e0"
version = "0.9.0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Makie]]
deps = ["Animations", "Base64", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Distributions", "DocStringExtensions", "FFMPEG", "FileIO", "FixedPointNumbers", "Formatting", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageIO", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MakieCore", "Markdown", "Match", "MathTeXEngine", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "Printf", "Random", "RelocatableFolders", "Serialization", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "UnicodeFun"]
git-tree-sha1 = "b0323393a7190c9bf5b03af442fc115756df8e59"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.17.13"

[[deps.MakieCore]]
deps = ["Observables"]
git-tree-sha1 = "fbf705d2bdea8fc93f1ae8ca2965d8e03d4ca98c"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.4.0"

[[deps.MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Match]]
git-tree-sha1 = "1d9bc5c1a6e7ee24effb93f175c9342f9154d97f"
uuid = "7eb4fadd-790c-5f42-8a69-bfa0b872bfbf"
version = "1.2.0"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "LinearAlgebra", "OrderedCollections", "SparseArrays", "Test", "Unicode"]
git-tree-sha1 = "78427dcc212e0c0ad9658049bc56a50303ad9737"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "0.9.7"

[[deps.MathProgBase]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9abbe463a1e9fc507f12a69e7f29346c2cdc472c"
uuid = "fdba3010-5040-5b88-9595-932c9decdf73"
version = "0.7.8"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "Test"]
git-tree-sha1 = "114ef48a73aea632b8aebcb84f796afcc510ac7c"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.4.3"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.MixedModels]]
deps = ["Arrow", "DataAPI", "Distributions", "GLM", "JSON3", "LazyArtifacts", "LinearAlgebra", "Markdown", "NLopt", "PooledArrays", "ProgressMeter", "Random", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "StatsFuns", "StatsModels", "StructTypes", "Tables"]
git-tree-sha1 = "eb09b8b591d0c2e551ef68c30810fd3d1bb7c946"
uuid = "ff71e718-51f3-5ec2-a782-8ffcbfa3c316"
version = "4.7.1"

[[deps.MixedModelsPermutations]]
deps = ["BlockDiagonals", "LinearAlgebra", "MixedModels", "Random", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "StatsModels", "Tables"]
git-tree-sha1 = "a08c290a3b4770866c25c732aad6b38d196a041e"
uuid = "647c4018-d7ef-4d03-a0cc-8889a722319e"
version = "0.1.4"

[[deps.MixedModelsSim]]
deps = ["LinearAlgebra", "MixedModels", "PooledArrays", "PrettyTables", "Random", "Statistics", "Tables"]
git-tree-sha1 = "96ce9a3dd9499fd679a4ffd494d339d50248da0e"
uuid = "d5ae56c5-23ca-4a1f-b505-9fc4796fc1fe"
version = "0.2.6"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "29714d0a7a8083bba8427a4fbfb00a540c681ce7"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.3"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "4e675d6e9ec02061800d6cfb695812becbd03cdf"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.0.4"

[[deps.NLopt]]
deps = ["MathProgBase", "NLopt_jll"]
git-tree-sha1 = "48d523294d66f34d012e224ec3082d35c395ebd2"
uuid = "76087f3c-5699-56af-9a33-bf431cd00edd"
version = "0.6.0"

[[deps.NLopt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9b1f15a08f9d00cdb2761dcfa6f453f5d0d6f973"
uuid = "079eb43e-fd8e-5478-9966-2cf3e3edb778"
version = "2.7.1+0"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "440165bf08bc500b8fe4a7be2dc83271a00c0716"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.12"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore"]
git-tree-sha1 = "18efc06f6ec36a8b801b23f076e3c6ac7c3bf153"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "dfd8d34871bc3ad08cd16026c1828e271d554db9"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.1"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "1ea784113a6aa054c5ebd95945fa5e52c2f378e7"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.12.7"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "923319661e9a22712f24596ce81c54fc0366f304"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.1+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e60321e3f2616584ff98f0a4f18d98ae6f89bbb3"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.17+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.40.0+0"

[[deps.PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "cf494dca75a69712a72b80bc48f59dcf3dea63ec"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.16"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "e925a64b8585aa9f4e3047b8d2cdc3f0e79fd4e4"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.16"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "1155f6f937fa2b94104162f01fa400e192e4272f"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.4.2"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "03a7a85b76381a3d04c7a1656039197e70eda03d"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.11"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a121dfbba67c94a5bec9dde613c3d0cbcf3a12b"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.50.3+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "0044b23da09b5608b4ecacb4e5e6c6332f833a7e"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.3.2"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.PkgBenchmark]]
deps = ["BenchmarkTools", "Dates", "InteractiveUtils", "JSON", "LibGit2", "Logging", "Pkg", "Printf", "TerminalLoggers", "UUIDs"]
git-tree-sha1 = "6e2856f677f8dcab289ded9c3ffb018fad38f29c"
uuid = "32113eaa-f34f-5b0d-bd6c-c81e245fc73d"
version = "0.2.10"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f6cf8e7944e50901594838951729a1861e668cb8"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.2"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "9888e59493658e476d3073f1ce24348bdc086660"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "8d1f54886b9037091edf146b517989fc4a09efec"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.39"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "MutableArithmetics", "RecipesBase"]
git-tree-sha1 = "8cc4b1a1d81b1db45dea3512040be7f0e84bfef9"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "3.1.6"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "d7a7aef8f8f2d537104f170139553b14dfe39fe9"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.2"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "53b8b07b721b77144a0fbbbc2675222ebf40a02d"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.94.1"

[[deps.PyMNE]]
deps = ["PyCall"]
git-tree-sha1 = "b3caa6ea95490974465487d54fc1e62a094bad8e"
uuid = "6c5003b2-cbe8-491c-a0d1-70088e6a0fd6"
version = "0.1.2"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.QPSReader]]
deps = ["Logging", "Pkg"]
git-tree-sha1 = "374833c0c1fd5cc623278581bf0c8259d7b35f10"
uuid = "10f199a5-22af-520b-b891-7ce84a7b1bd0"
version = "0.2.1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "dc84268fe0e3335a62e315a3a7cf2afa7178a734"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.3"

[[deps.RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "22c5201127d7b243b9ee1de3b43c408879dff60f"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.3.0"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Richardson]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "e03ca566bec93f8a3aeb059c8ef102f268a38949"
uuid = "708f8203-808e-40c0-ba2d-98a6953ed40d"
version = "1.4.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.RobustModels]]
deps = ["Distributions", "Future", "GLM", "IterativeSolvers", "LinearAlgebra", "Printf", "QuadGK", "Random", "Roots", "SparseArrays", "Statistics", "StatsBase", "StatsModels", "Tulip"]
git-tree-sha1 = "1363a09a9e58b5a0c7230c98086cd50c77929f53"
uuid = "d6ea1423-9682-4bbd-952f-b1577cbf8c98"
version = "0.4.3"

[[deps.Roots]]
deps = ["CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "838b60ee62bebc794864c880a47e331e00c47505"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "1.4.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
git-tree-sha1 = "7dbc15af7ed5f751a82bf3ed37757adf76c32402"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.4.1"

[[deps.ScanByte]]
deps = ["Libdl", "SIMD"]
git-tree-sha1 = "2436b15f376005e8790e318329560dcc67188e84"
uuid = "7b38b023-a4d7-4c5e-8d43-3f3097f304eb"
version = "0.3.3"

[[deps.ScatteredInterpolation]]
deps = ["Combinatorics", "Distances", "LinearAlgebra", "NearestNeighbors"]
git-tree-sha1 = "0d642a08199bbeccd874b33fe3a1b699d345ca79"
uuid = "3f865c0f-6dca-5f4d-999b-29fe1e7e3c92"
version = "0.3.6"

[[deps.SciPy]]
deps = ["InteractiveUtils", "PyCall"]
git-tree-sha1 = "851671edd821b975dcaa720d1da1541b4c1951ce"
uuid = "ebc72ef8-9537-4fb0-b64e-ac76025fed2d"
version = "0.1.1"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "f94f779c94e58bf9ea243e77a37e16d9de9126bd"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "db8481cf5d6278a121184809e9eb1628943c7704"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.13"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "38d88503f695eb0301479bc9b0d4320b378bafe5"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.8.2"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.ShiftedArrays]]
git-tree-sha1 = "22395afdcf37d6709a5a0766cc4a5ca52cb85ea0"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "1.0.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "8fb59825be681d451c246a795117f317ecbcaa28"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.2"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "23368a3313d12a2326ad0035f0db0c0966f438ef"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "66fe9eb253f910fe8cf161953880cfdaef01cdf0"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.0.1"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "5950925ff997ed6fb3e985dcce8eb1ba42a0bbe7"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.18"

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "f8ba54b202c77622a713e25e7616d618308b34d3"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.6.31"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "ec47fb6069c57f1cee2f67541bf8f23415146de7"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.11"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "d24a825a95a6d98c385001212dc9020d609f2d4f"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.8.1"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.TerminalLoggers]]
deps = ["Logging", "Printf"]
git-tree-sha1 = "987a3ebb20307530775f4def7eb9109cfa881748"
uuid = "5d786b92-1e48-4d6f-9151-6b4477ca9bed"
version = "0.1.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "70e6d2da9210371c927176cb7a56d41ef1260db7"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.6.1"

[[deps.TimeZones]]
deps = ["Dates", "Downloads", "InlineStrings", "LazyArtifacts", "Mocking", "Printf", "RecipesBase", "Scratch", "Unicode"]
git-tree-sha1 = "d634a3641062c040fc8a7e2a3ea17661cc159688"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.9.0"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "464d64b2510a25e6efe410e7edab14fffdc333df"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.20"

[[deps.TopoPlots]]
deps = ["Delaunay", "Dierckx", "GeometryBasics", "InteractiveUtils", "LinearAlgebra", "Makie", "Parameters", "PyCall", "ScatteredInterpolation", "SciPy", "Statistics"]
git-tree-sha1 = "c9de2ed6f08bcbab66fa5d55f3f9f9983b4c0757"
uuid = "2bdbdf9c-dbd8-403f-947b-1a4e0dd41a7a"
version = "0.1.2"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.Tulip]]
deps = ["CodecBzip2", "CodecZlib", "Krylov", "LDLFactorizations", "LinearAlgebra", "LinearOperators", "Logging", "MathOptInterface", "Printf", "QPSReader", "SparseArrays", "SuiteSparse", "Test", "TimerOutputs"]
git-tree-sha1 = "753c5bd161ca2a64da995a21900bcc177bd7d8e4"
uuid = "6dd1b50a-3aae-11e9-10b5-ef983d2400fa"
version = "0.8.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unfold]]
deps = ["BSplines", "CategoricalArrays", "DSP", "DataFrames", "Distributions", "DocStringExtensions", "Effects", "GLM", "IncompleteLU", "IterativeSolvers", "LinearAlgebra", "Logging", "MLBase", "Missings", "MixedModels", "MixedModelsPermutations", "MixedModelsSim", "PkgBenchmark", "ProgressMeter", "PyMNE", "Random", "RobustModels", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "StatsFuns", "StatsModels", "Tables", "Test", "TimerOutputs"]
git-tree-sha1 = "6137a1e288f9655a88bd62c34ea91ee7d0ffd01c"
uuid = "181c99d8-e21b-4ff3-b70b-c233eddec679"
version = "0.3.11"

[[deps.UnfoldMakie]]
deps = ["AlgebraOfGraphics", "DataFrames", "Makie", "SparseArrays", "Statistics", "Unfold"]
git-tree-sha1 = "fc328102a4794f211dcf23e1fa7f8bb03030a2cd"
uuid = "69a5ce3b-64fb-4f22-ae69-36dd4416af2a"
version = "0.1.4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[deps.XDF]]
deps = ["Logging"]
git-tree-sha1 = "ab2aab5ba6a7270cd51d0e99c5873b18d1dc5d72"
uuid = "31bc19ec-0089-417f-990e-a2b5e7515868"
version = "0.2.0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "58443b63fb7e465a8a7210828c91c08b92132dff"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.14+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "78736dab31ae7a53540a6b752efc61f77b304c5b"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.8.6+1"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"
"""

# ╔═╡ Cell order:
# ╟─0f65f18b-cfc9-4ad5-97a8-eb4dc634fb31
# ╟─18d9b04e-0d71-4d09-8145-50bfcd125cd2
# ╠═16b920a4-08d5-11ed-3512-8b6269563ef3
# ╠═d22822f9-6f8d-401f-b7c4-a00b4520a4bb
# ╟─35004d67-c8cb-417d-9724-3dca1fd6990c
# ╠═e35af0f8-2e06-46bf-b861-4a1f01f655f9
# ╠═edf18493-eb61-4f51-8fb1-528f826f5dfe
# ╠═75764ab2-cf18-4db1-9b93-a09a077679fa
# ╟─c5d9548f-8f56-411b-ab9c-afcef6e93590
# ╟─f96bd399-346a-4152-a0c3-cfe99d62e472
# ╟─71ec0643-6513-4d38-b927-7b15833b1f14
# ╠═f8e06052-68f3-4902-b81a-fd2bd1569c89
# ╟─f2514060-fc56-41f2-adfb-c09a480b5fce
# ╠═b265f60b-7b97-4247-ae05-cc273eddda09
# ╟─473035e0-010a-400b-81f6-543906f2f33a
# ╠═8cf3ce68-fb9e-45f0-b596-3f36ff57de11
# ╟─90fe4492-4d9f-4d28-b4cb-f90d465d2bc1
# ╠═e710c8c3-520e-464c-b350-f28f7d06c746
# ╟─06454fb3-dc98-4bb2-952b-673aaf79915e
# ╠═7c333ba8-60d6-4be1-ba71-7747eda58529
# ╟─5d14aefb-eb45-4545-a6d4-a33f59017619
# ╠═b22a312d-df68-4768-84ca-3079255c4ea0
# ╟─f50769a6-e30e-40f9-9e42-bfb49155b789
# ╠═d658b65b-2e51-4784-8541-18cd8bb7b233
# ╟─ca6a9d5a-dfd9-4e51-b540-f7cdfb0e376e
# ╠═25d3d8e1-6b21-46f0-858c-5b465b7d2a06
# ╟─b85a894e-8fbc-4344-9ff6-3fc6662882b3
# ╠═40236ca2-4f3d-4055-876c-b803ffda22c7
# ╠═f3c4c9d9-cc08-4851-888a-851c104b5067
# ╟─586838f2-b504-4cef-8183-4e043d286080
# ╟─9dd3f057-b6b0-4da3-abfe-30970b596110
# ╠═93564e62-7031-42c7-bca5-edff000e0835
# ╟─b16029f8-c699-463c-8d4f-986daa0a7c75
# ╠═0b585aea-a3f4-4adf-b05f-1d37664accd2
# ╟─84b6804a-b5c5-4033-9d53-75f99a21ba52
# ╠═f6cc51ad-8ae9-469a-9f59-0fa3169fe59b
# ╟─21e58f39-0709-4508-94dd-a79b1d15bc6f
# ╠═bbbf6573-f932-41a4-82b2-4c00f0576387
# ╠═8784b190-d872-4e02-bb14-147a17be8b0e
# ╟─de576896-bfa3-4c5d-910d-375dff2a43e6
# ╟─d66806f8-d57d-4f7e-9414-2f3971954912
# ╠═7a2eea8b-bada-46cd-8adc-5a41f4bb60be
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
