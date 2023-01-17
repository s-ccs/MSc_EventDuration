function EEG = add_ica(EEG,mods,plot,bad_comps_outdir)

EEGica = pop_eegfiltnew(EEG, 'locutoff',1.5);

if isfield(mods,'A')
    % we got a amica
model_index = 1;
EEGica.icawinv = mods.A(:,:,model_index);
EEGica.icaweights = mods.W(:,:,model_index);
EEGica.icasphere = mods.S(1:size(mods.W,1),:);
EEGica.icachansind = 1:size(EEGica.data,1);
else
       
        EEGica.icawinv = mods.icawinv;
        EEGica.icaweights = mods.icaweights;
        EEGica.icasphere = mods.icasphere;
        EEGica.icachansind = 1:size(EEGica.data,1);

end
EEGica = eeg_checkset(EEGica);

EEGica = pop_iclabel(EEGica,'default');
EEGica = pop_icflag(EEGica,[NaN NaN;0.8 1;0.8 1;0.8 1;0.8 1;0.8 1;0.8 1]);



if ~exist(bad_comps_outdir, 'dir');        mkdir(bad_comps_outdir);    end

if plot
    display("plotting")
    fh = figure('Visible','off');
    % add fake button
    pop_viewprops(EEGica, 0,1:55,[],[],[],[],fh) 
    
    %pop_viewprops( EEG, typecomp, chanorcomp, spec_opt, erp_opt, scroll_event, classifier_name, fig)
    %saveas(gcf,fullfile(bad_comps_outdir,'all-comps_topoplot'),'png')
    close(gcf)
    %for Ci = 1:size(EEGica.icawinv,2)
        
    %    h = pop_prop_extended(EEGica, 0, Ci, NaN, { 'freqrange' [1 80] }, {'erp', 'on'}, 0, 'ICLabel');
        
    %    saveas(h, fullfile(bad_comps_outdir, sprintf("bad-%i_comp-%i",EEGica.reject.gcompreject(Ci),Ci)), 'png')
    %    close(h)
    %end
    
end

% copy over ICA to unfiltered EEG
EEG.icaweights = EEGica.icaweights;
EEG.icawinv = EEGica.icawinv;
EEG.icasphere = EEGica.icasphere;
EEG.icachansind = EEGica.icachansind;
EEG.reject.gcompreject = EEGica.reject.gcompreject;
EEG.etc.ICLabel = EEGica.etc.ic_classification.ICLabel;
EEG.etc.comp_rejected = find(EEGica.reject.gcompreject);

EEG = pop_subcomp(EEG, find(EEG.reject.gcompreject), 0);

end