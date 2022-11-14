### A Pluto.jl notebook ###
# v0.19.14

using Markdown
using InteractiveUtils

# ╔═╡ 1418c388-bdcd-4db6-a624-90261de23cdc
begin
	using CSV
	using DataFrames
	using Printf
end

# ╔═╡ 1d6716ed-bf33-4898-9ce4-a8ebb6ef062f
md"### 0. Import Packages"

# ╔═╡ b7fb3c90-91cc-40a0-8f29-effbdde3c989
md"### 1. Import Events"

# ╔═╡ ca10ac9c-52e0-11ed-1a2c-11746c721dbf
begin
	subList = ["005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "028" "029" "030" "031" "032" "033" "034" "035" "036" "037" "038" "039" "040" "041"]
	task = "Oddball"
	sfreq = 256
end;

# ╔═╡ 40c92775-7e81-4840-9f0d-b390666f89f7
function loadSub(sub,task)
	# Load events
	events = CSV.read("/store/data/MSc_EventDuration/sub-"*sub*"/ses-001/eeg/sub-"*sub*"_ses-001_task-"*task*"_run-001_events.tsv",DataFrame, delim="\t")

	# Add subject to DataFrame to easily subset when not looking at all subjects
	events[!,:subject] .= parse.(Int64,sub)
	
	return events
end;

# ╔═╡ 716fab00-22c4-4b4b-9473-f026a754b107
begin
	eventsAllList = Array{DataFrame}(undef,length(subList))

for (ix, sub) in enumerate(subList)
	events = loadSub(sub,task)
	eventsAllList[ix] = events
end
end;

# ╔═╡ 4b72308e-fbcc-479d-a41d-f0867dbde2f6
md"### 2. Adapt Events"

# ╔═╡ cafb84a1-4abd-47e9-9bb3-ac4402887e25
begin
	relevantEvents = CSV.read("/home/geiger/2022-MSc_EventDuration/code/analysis/results/relevantEvents/relevantEventsOddball.csv",DataFrame, delim=",")

	shiftLSLOffset = -0.005
	sfreq_recording = 1000

	eventsList = Array{DataFrame}(undef,length(subList))
	
	for (ix,subject) in enumerate(subList)
		subject = parse(Int64,subject)

		# Use LSL markers for latency
		eventsAllList[ix][!,:latency] .= zeros(size(eventsAllList[ix],1))
		blockStarts = findall(occursin.("blockStart",eventsAllList[ix].trial_type))
		blockEnds = findall(occursin.("blockEnd",eventsAllList[ix].trial_type))

		for i = 1:size(blockStarts,1)
			# LSL markers start from 0.0 s on each block --> need to calculate correct latency: shift each latency by sample of corresponding blockStart
			shiftBlock = eventsAllList[ix].sample[blockStarts[i]]/sfreq_recording
			# Correct 5 ms offset of lsl markers and adjust latency to downsampling
			for j = blockStarts[i]:blockEnds[i]
				eventsAllList[ix].latency[j] = (eventsAllList[ix].onset[j] + shiftBlock + shiftLSLOffset) * sfreq
			end
		end
		
		# Remove irrelevant events
		relevantEventsSub = relevantEvents[in([subject]).(relevantEvents.subject),:]
		eventsList[ix] = eventsAllList[ix][findall(isone,relevantEventsSub.KeepOrRemoveEvent),:]
	end

	for (ix, subject) in enumerate(subList)
		
		# Remove trailing whitespaces from string columns
		eventsList[ix].trial_type = strip.(eventsList[ix].trial_type)
		eventsList[ix].condition = strip.(eventsList[ix].condition)
		eventsList[ix].target_response = strip.(eventsList[ix].target_response)

		# Map buttonpress events to target or distracter trials
		ixBP = findall(occursin.("buttonpress",eventsList[ix].trial_type))
		for i in ixBP[1:end]
			if cmp(eventsList[ix].condition[i],"target")==0
				eventsList[ix].trial_type[i] = "bp_target"
			elseif cmp(eventsList[ix].condition[i],"distractor")==0
				eventsList[ix].trial_type[i] = "bp_distractor"
			end
		end
	end
end;

# ╔═╡ 6d975c93-563c-427d-83b6-6a150bf7d0c8
# Add columns for dummy and treatment coding
begin
	for (ix,subject) in enumerate(subList)
		eventsList[ix].event_type 		= deepcopy(eventsList[ix].trial_type)
		eventsList[ix][!,:bp_target] 	.= Int.(zeros(size(eventsList[ix],1)))
		eventsList[ix][!,:bp_distractor].= Int.(zeros(size(eventsList[ix],1)))
		eventsList[ix][!,:target] 		.= Int.(zeros(size(eventsList[ix],1)))
		eventsList[ix][!,:distractor] 	.= Int.(zeros(size(eventsList[ix],1)))

		targetbps = findall(occursin.("bp_target",eventsList[ix].trial_type))
		distractorbps = findall(occursin.("bp_distractor",eventsList[ix].trial_type))
		targets = findall(occursin.("target",eventsList[ix].condition))
		distractors = findall(occursin.("distractor",eventsList[ix].condition))

		for i = 1:size(eventsList[ix],1)
			if i ∈ targetbps
				eventsList[ix].bp_target[i] = 1
			elseif i ∈ distractorbps
				eventsList[ix].bp_distractor[i] = 1
			elseif i ∈ targets
				eventsList[ix].target[i] = 1
			elseif i ∈ distractors
				eventsList[ix].distractor[i] = 1				
			end
			if eventsList[ix].trial_type[i] == "stimOnset"
				eventsList[ix].trial_type[i] = eventsList[ix].condition[i]
			end
			if eventsList[ix].trial_type[i] == "target"
				eventsList[ix].event_type[i] = "stimulus"
			elseif eventsList[ix].trial_type[i] == "distractor"
				eventsList[ix].event_type[i] = "stimulus"
			elseif eventsList[ix].trial_type[i] == "bp_target"
				eventsList[ix].event_type[i] = "response"
			elseif eventsList[ix].trial_type[i] == "bp_distractor"
				eventsList[ix].event_type[i] = "response"
			end
		end		
		# Remove unnecessary columns
		select!(eventsList[ix], Not([:onset,:duration,:sample,:condition,:keycode,:target_response]))
		# Reorder remaining columns
		eventsList[ix] = eventsList[ix][!,[:latency,:response_time,:event_type,:trial_type,:target,:distractor,:bp_target,:bp_distractor,:subject]]
	end
end

# ╔═╡ 7df3832d-fb65-473e-a822-3c9af3ea004e
md"### 3. Remove Artefacts"

# ╔═╡ f3bb3c5c-e9a9-4753-be7a-673308a5d21e
begin
	for (ix, subject) in enumerate(subList)
		asr = CSV.read("/store/data/non-bids/MSc_EventDuration/derivatives/ASRcleaning_Oddball/sub-"*subject*"/sub-"*subject*"_desc-ASRCleaningTimes.tsv",DataFrame, delim="\t",header=false)

	for i in 1:size(asr,1)
		eventsList[ix] = filter(row->!(round(row.latency) ∈ range(start=asr.Column1[i]-sfreq,stop = asr.Column2[i]+sfreq,step=0.1)),eventsList[ix])
	end
	end
end

# ╔═╡ 42a282f2-9f44-4318-88bc-a507a016a364
md"### 4. Export Events"

# ╔═╡ c711e9b0-203a-426f-88a2-b2d38c451d38
for (ix, subject) in enumerate(subList)
	CSV.write(@sprintf("/home/geiger/2022-MSc_EventDuration/code/analysis/results/relevantEvents/%s_finalEvents.csv",subject),eventsList[ix])
	println("subject ",subject,":  ",size(eventsList[ix]))
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[compat]
CSV = "~0.10.4"
DataFrames = "~1.4.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.0"
manifest_format = "2.0"
project_hash = "0c32d1d2b58aef5f4d9f31d0a5cea5a75f9edfc8"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "873fb188a4b9d76549b81465b1f75c82aaf59238"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.4"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "3ca828fe1b75fa84b021a7860bd039eaea84d2f2"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.3.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "46d2680e618f8abd007bce0c3026cb0c4a8f2032"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.12.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SnoopPrecompile", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "558078b0b78278683a7445c626ee78c86b9bb000"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.4.1"

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

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "d0ca109edbae6b4cc00e751a29dcb15a124053d6"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.2.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "3d5bf43e3e8b412656404ed9466f1dcbf7c50269"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.4.0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "460d9e154365e058c4d886f6f7d6df5ffa1ea80e"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.1.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "c0f56940fc967f3d5efed58ba829747af5f8b586"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.15"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SnoopPrecompile]]
git-tree-sha1 = "f604441450a3c0569830946e5b33b78c928e1a85"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.1"

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

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "2d7164f7b8a066bcfa6224e67736ce0eb54aef5b"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.9.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "8a75929dcd3c38611db2f8d08546decb514fcadf"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.9"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"
"""

# ╔═╡ Cell order:
# ╟─1d6716ed-bf33-4898-9ce4-a8ebb6ef062f
# ╠═1418c388-bdcd-4db6-a624-90261de23cdc
# ╟─b7fb3c90-91cc-40a0-8f29-effbdde3c989
# ╠═ca10ac9c-52e0-11ed-1a2c-11746c721dbf
# ╠═40c92775-7e81-4840-9f0d-b390666f89f7
# ╠═716fab00-22c4-4b4b-9473-f026a754b107
# ╟─4b72308e-fbcc-479d-a41d-f0867dbde2f6
# ╠═cafb84a1-4abd-47e9-9bb3-ac4402887e25
# ╠═6d975c93-563c-427d-83b6-6a150bf7d0c8
# ╟─7df3832d-fb65-473e-a822-3c9af3ea004e
# ╠═f3bb3c5c-e9a9-4753-be7a-673308a5d21e
# ╟─42a282f2-9f44-4318-88bc-a507a016a364
# ╠═c711e9b0-203a-426f-88a2-b2d38c451d38
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
