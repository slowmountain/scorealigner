function varargout = score_aligner(varargin)
% SCORE_ALIGNER Simple score alignment software based on the Online Time
% Warping (OLTW) algorithm by Simon Dixon.
%
% Simply run score_aligner.m to start.
%
% Author: Panos Papiotis (panos.papiotis@upf.edu), Music Technology Group,
% Universitat Pompeu Fabra
% 

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @score_aligner_OpeningFcn, ...
                   'gui_OutputFcn',  @score_aligner_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before score_aligner is made visible.
function score_aligner_OpeningFcn(hObject, eventdata, handles, varargin)

% Choose default command line output for score_aligner
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
try
% Set up some global variables
clear global;
global AudioFileLoaded MIDIFileLoaded mscore_path alignedscore exec_path handles synthesize;
AudioFileLoaded = uint8(0);
MIDIFileLoaded = uint8(0);
mscore_path = '"C:\Program Files\MuseScore\bin\mscore"';
alignedscore = 0;
set(handles.windowsize_popup,'Value',4);
exec_path = pwd;
synthesize = 0;

% TODO: This used to offer the functionality of a .settings file to store
% default aligner settings. It's disabled for the time being.

% % Open optional settings file
% fid = fopen('score_aligner.settings');
% if (fid ~= -1)
%     % musescore path
%     line = fgetl(fid);
%     tokens = regexp(line,'=','split');
%     if ~ismac
%         mscore_path = tokens{end};
%     end
%     % window size
%     line = fgetl(fid);
%     tokens = regexp(line,'=','split');
%     set(handles.windowsize_popup,'Value',str2num(tokens{end}));
%     % feature used
%     line = fgetl(fid);
%     tokens = regexp(line,'=','split');
%     set(handles.feature_popup,'Value',str2num(tokens{end}));
%     % distance metric
%     line = fgetl(fid);
%     tokens = regexp(line,'=','split');
%     set(handles.distance_popup,'Value',str2num(tokens{end}));
%     % synthesize aligned
%     line = fgetl(fid);
%     tokens = regexp(line,'=','split');
%     set(handles.synthesize_toggle,'Value',str2num(tokens{end}));
% end

if ismac
    path1 = getenv('PATH');
    path1 = [path1 ':/opt/local/bin/'];
    setenv('PATH', path1)
    clear path1;
end

set(handles.svl_checkbox,'Value',0);

catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);
    errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error on startup');
end

% --- Outputs from this function are returned to the command line.
function varargout = score_aligner_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;


% --- Executes on selection change in distance_popup.
function distance_popup_Callback(hObject, eventdata, handles)


% --- Executes during object creation, after setting all properties.
function distance_popup_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in align_button.
function align_button_Callback(hObject, eventdata, handles)
global reference score REF SCOR p q C SM windowsize sr srMIDI alignedscore score_nmat aligned_score_nmat onsets exec_path map stopalignment startSample endSample;
try
watchon;

set(handles.status_label,'String','Aligning...')
set(handles.stopalignment_button,'Enable','on');
drawnow;
searchwidth = get(handles.searchwidth_slider,'Value');
maxRunCount = max([floor(length(REF(1,:))/length(SCOR(1,:))) floor(length(SCOR(1,:))/length(REF(1,:)))]);
if(get(handles.distance_popup,'Value')==1)
    [p,q,C,SM] = oltw(REF,SCOR,'cosine',round(((size(SCOR,2)+size(REF,2))/2)*searchwidth),maxRunCount,handles);
else
    [p,q,C,SM] = oltw(REF,SCOR,'euclidean',round(((size(SCOR,2)+size(REF,2))/2)*searchwidth),maxRunCount,handles);
end
set(handles.figure1,'CurrentAxes',handles.simmx_plot);
title('Distance matrix and alignment path');
imagesc(SM);
hold on; plot(q,p,'r'); hold off;
if(get(handles.distance_popup,'Value')==1)
    colormap(1-gray);
else
    colormap(gray);
end
clear global C;

% Calculate the new onset positions
map = zeros(size(SM,2),1);
for i = 1:size(SM,2)
    if (~isempty(p(min(find(q==i)))))
        map(i) = p(min(find(q==i)));
    end
end
map = map*(windowsize/(2*srMIDI));

aligned_score_nmat = score_nmat;

for i=1:size(score_nmat,1)
    timeOffset = startSample/srMIDI;
    % Onset value:
    % Rounded value of onset
    roundedValue = map(min(max(floor((score_nmat(i,6)*srMIDI)/(windowsize/2)),1),length(map)));
    % Rounding percent
    roundingPercent = ((score_nmat(i,6)*srMIDI)/(windowsize/2)-floor((score_nmat(i,6)*srMIDI)/(windowsize/2)));
    % Rounding error correction
    roundingError = roundingPercent*(map(min(max(ceil((score_nmat(i,6)*srMIDI)/(windowsize/2)),1),length(map)))-map(min(max(floor((score_nmat(i,6)*srMIDI)/(windowsize/2)),1),length(map))));
    % Final calculated onset value
    aligned_score_nmat(i,6) = roundedValue+roundingError+timeOffset;
    
    % Offset value:
    % Rounded value of offset
    roundedValue = map(max(min(floor(((score_nmat(i,6)+score_nmat(i,7))*srMIDI)/(windowsize/2)),length(map)),1));
    % Rounding percent
    roundingPercent = (((score_nmat(i,6)+score_nmat(i,7))*srMIDI)/(windowsize/2)-floor(((score_nmat(i,6)+score_nmat(i,7))*srMIDI)/(windowsize/2)));
    % Rounding error correction
    roundingError = roundingPercent*(map(min(max(ceil(((score_nmat(i,6)+score_nmat(i,7))*srMIDI)/(windowsize/2)),1),length(map)))-map(min(max(floor(((score_nmat(i,6)+score_nmat(i,7))*srMIDI)/(windowsize/2)),1),length(map))));
    % Final calculated offset value
    aligned_score_nmat(i,8) = roundedValue+roundingError+timeOffset;
    
    % Duration value:
    aligned_score_nmat(i,7) = aligned_score_nmat(i,8)-aligned_score_nmat(i,6);
end

multiplier = unique((round(1000*(score_nmat(2:end,1)./score_nmat(2:end,6)))/1000));
multiplier(isnan(multiplier)) = [];
aligned_score_nmat(:,1) = multiplier.*aligned_score_nmat(:,6);
aligned_score_nmat(:,2) = multiplier.*aligned_score_nmat(:,7);

% Correct possible overlapping onsets/offsets
instruments = unique(aligned_score_nmat(:,3));
for j=1:length(length(unique(aligned_score_nmat(:,3))))
    lastOffset = 0;
    lastNote = 1;
    for i=1:length(aligned_score_nmat(:,1))
        if (aligned_score_nmat(i,3)==instruments(j))
            if (aligned_score_nmat(i,6)-lastOffset<0.03)
                aligned_score_nmat(lastNote,8) = aligned_score_nmat(i,6);
            end
            lastNote = i;
            lastOffset = aligned_score_nmat(i,8);
        end
    end
end

set(handles.figure1,'CurrentAxes',handles.waveforms_plot);
hold on;
if(ishandle(onsets))
    delete(onsets);
end

% Enable the plot tools checkboxes & slider
set(handles.plottedsignals_label,'Enable','on')
set(handles.featuresplots_label,'Enable','on')
set(handles.score_checkbox,'Enable','on')
set(handles.audio_checkbox,'Enable','on')
set(handles.alignedscore_checkbox,'Enable','off')
set(handles.plotalignedfeature_checkbox,'Enable','off')
set(handles.listen_button,'Enable','off')
set(handles.linkaxes_checkbox,'Enable','on')
set(handles.clear_button,'Enable','on')
set(handles.savealignment_button,'Enable','on')
set(handles.svl_label,'Enable','on');
set(handles.svl_checkbox,'Enable','on');
set(handles.synthesize_button,'Enable','on')
set(handles.stopalignment_button,'Enable','off');
set(handles.status_label,'String',['Alignment performed succesfully.'])
watchoff;
beep;
catch err
    beep;
    watchoff;
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);
    errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error during alignment');
end


% --- Executes on selection change in windowsize_popup.
function windowsize_popup_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function windowsize_popup_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in feature_popup.
function feature_popup_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function feature_popup_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in analyze_button.
function analyze_button_Callback(hObject, eventdata, handles)
global reference score REF SCOR windowsize sr srMIDI exec_path;
try
watchon;
set(handles.status_label,'String','Extracting features...');
drawnow;
% Get the window size from the pop-up menu
windowsize = 2^(8+get(handles.windowsize_popup,'Value'));
if(get(handles.feature_popup,'Value')==1)
    % Get the spectrum
    REF = [zeros((windowsize/2)+1,1) single(abs(specgram(reference,windowsize,srMIDI,windowsize,windowsize/2)))];
    SCOR = [zeros((windowsize/2)+1,1) single(abs(specgram(score,windowsize,srMIDI,windowsize,windowsize/2)))];
elseif(get(handles.feature_popup,'Value')==2)
    % Get chroma
    REF = [zeros(12,1) single(chromagram_IF(reference,srMIDI,windowsize,12))];
    SCOR = [zeros(12,1) single(chromagram_IF(score,srMIDI,windowsize,12))];
elseif(get(handles.feature_popup,'Value')==3)
    % Get chroma diff
    REF = diff([zeros(12,2) single(chromagram_IF(reference,srMIDI,windowsize,12))],1,2);
    SCOR = diff([zeros(12,2) single(chromagram_IF(score,srMIDI,windowsize,12))],1,2);
end
% Plot the extracted feature
set(handles.figure1,'CurrentAxes',handles.features_plot1);
imagesc(REF);
colormap(hot);
freezeColors;
set(handles.figure1,'CurrentAxes',handles.features_plot2);
imagesc(SCOR);
colormap(hot);
freezeColors;
set(handles.features_plot1,'YTick',[])
set(handles.features_plot2,'YTick',[])
if(get(handles.feature_popup,'Value')==1)
    set(handles.features_plot1,'YLim',[0 windowsize/16]);
    set(handles.features_plot2,'YLim',[0 windowsize/16]);
end
myXTick1 = get(handles.features_plot1,'XTick');
for i=1:length(myXTick1);myXTickLabel1{i}=int2str((myXTick1(i)*(windowsize/2))/srMIDI);end;
myXTick2 = get(handles.features_plot2,'XTick');
for i=1:length(myXTick2);myXTickLabel2{i}=int2str((myXTick2(i)*(windowsize/2))/srMIDI);end;
set(handles.features_plot1,'XTickLabel',myXTickLabel1)
set(handles.features_plot2,'XTickLabel',myXTickLabel2)
% Enable the align buttons
set(handles.align_button,'Enable','on');
set(handles.distance_popup,'Enable','on');
set(handles.distance_label,'Enable','on');
set(handles.searchwidth_label,'Enable','on');
set(handles.searchwidth_slider,'Enable','on');
set(handles.clearplots_button,'Enable','on');
beep;watchoff;
set(handles.status_label,'String','Ready to align.')
catch err
    beep;watchoff;
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error during analysis');
end

% --- Executes on button press in openaudio_button.
function openaudio_button_Callback(hObject, eventdata, handles)
global AudioFileLoaded MIDIFileLoaded reference score sr AudioFileName exec_path MIDIPathName AudioPathName startSample endSample;

try
if(AudioFileLoaded==1)
    set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
    cla;
    if(MIDIFileLoaded==1)        
        plot(score,'r');
    end
end    
% Launch a file chooser window
set(findobj('Tag','status_laould bel'),'String','Opening audio file...')
if(MIDIFileLoaded==1)
    if ~ismac
        [AudioFileName,AudioPathName] = uigetfile({'*.wav';'*.mp3'},'Select the audio file you want to analyze...',MIDIPathName);
    else
        [AudioFileName,AudioPathName] = uigetfile({'*.wav'},'Select the audio file you want to analyze...',MIDIPathName);
    end
else
    if ~ismac
        [AudioFileName,AudioPathName] = uigetfile({'*.wav';'*.mp3'},'Select the audio file you want to analyze...');
    else
        [AudioFileName,AudioPathName] = uigetfile({'*.wav'},'Select the audio file you want to analyze...');
    end
end

if (AudioFileName ~= 0)
    AudioFileLoaded = uint8(1);
else
    AudioFileLoaded = uint8(0);
    set(handles.status_label,'String','No audio file loaded.')
end

if (AudioFileLoaded)
    % Load the audio file
    [~,~,file_extension] = fileparts(AudioFileName);
    
    % TODO: mp3read won't work on OSX
    if strcmp(file_extension,'.mp3')
      [reference, sr] = mp3read([AudioPathName AudioFileName]);
    else
      [reference, sr] = wavread([AudioPathName AudioFileName]);
    end
    if (sr~=44100)
        reference = resample(reference,44100,sr);
    end
    reference = single(reference);
    % Convert from stereo to mono, if needed
    if(size(reference,2)) == 2; reference = mean(reference')'; end    
    % Normalize the waveform
    reference = reference/max(abs(reference));
    % TODO: This doesn't seem to work as intended
    % Check for silence and give the user the chance to set START and END
    % markers
    refRMS = rms(reference,8192,4096);
    for i=2:length(refRMS)
        refRMS(i) = refRMS(i-1)+refRMS(i);
    end
    silenceIndex = find(refRMS/max(refRMS)>0.05);
    startOfSound = silenceIndex(1);
    refRMS = rms(reference,8192,4096);
    for i=length(refRMS)-1:-1:2
        refRMS(length(refRMS)-i) = refRMS(i-1)+refRMS(i);
    end
    silenceIndex = find(refRMS/max(refRMS)>0.05);
    endOfSound = length(refRMS)-silenceIndex(1);
    startSample = 1;
    endSample = length(reference);
    if ((startOfSound+(length(refRMS)-endOfSound))/length(refRMS)>0.0)
        resizeReference = strcmp('Yes',questdlg(['Would you like to choose a segment of the audio instead of the whole recording?'],'Choose segment','Yes','No','Yes'));
        if (resizeReference)
            h = choose_segment;
            uiwait(h);
            reference = reference(startSample:endSample);
        end
    end
    
    % Update the status label
    set(handles.status_label,'String',[AudioFileName ' loaded with success!'])
    set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
    hold on;plot(reference);hold off;
    set(handles.waveforms_plot,'XLim',[0 length(reference)]);
    myXTick = (linspace(1,floor(length(reference)/44100),floor(length(reference)/44100))*44100*10);
    set(handles.waveforms_plot,'XTick',myXTick);
    for i=1:length(myXTick);myXTickLabel{i}=int2str(myXTick(i)/44100);end;
    set(handles.waveforms_plot,'XTickLabel',myXTickLabel);
    if (MIDIFileLoaded)
        % Enable the analysis buttons
        set(handles.analyze_button,'Enable','on')
        set(handles.windowsize_popup,'Enable','on')
        set(handles.feature_popup,'Enable','on')
        set(handles.windowsize_label,'Enable','on')
        set(handles.feature_label,'Enable','on')
        % Update the status label
        set(handles.status_label,'String','Ready for analysis.')
    end
    
end
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error loading audio file');
end

% --- Executes on button press in openmidi_button.
function openmidi_button_Callback(hObject, eventdata, handles)
global AudioFileLoaded MIDIFileLoaded mscore_path reference score srMIDI score_nmat exec_path AudioPathName MIDIPathName;
try
if(MIDIFileLoaded==1)
    set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
    cla;
    if(AudioFileLoaded==1)
        plot(reference,'b');
        set(handles.waveforms_plot,'XLim',[0 length(reference)]);
        myXTick = (linspace(1,floor(length(reference)/srMIDI),floor(length(reference)/srMIDI))*srMIDI*10);
        set(handles.waveforms_plot,'XTick',myXTick);
        for i=1:length(myXTick);myXTickLabel{i}=int2str(myXTick(i)/srMIDI);end;
        set(handles.waveforms_plot,'XTickLabel',myXTickLabel);
    end
end 
% Launch a file chooser window
set(handles.status_label,'String','Opening MIDI file...')
if (AudioFileLoaded==1)
    [MIDIFileName,MIDIPathName] = uigetfile({'*.mid'},'Select the MIDI score you want to align...',AudioPathName);
else
    [MIDIFileName,MIDIPathName] = uigetfile({'*.mid'},'Select the MIDI score you want to align...');
end
if (MIDIFileName ~= 0)
    MIDIFileLoaded = 1;
else
    MIDIFileLoaded = 0;
    set(handles.status_label,'String','No MIDI file loaded.')
end

if (MIDIFileLoaded)
    if ~ismac
        % TODO: allow the user to supply a custom path to the mscore binary
        [~,msg] = dos([mscore_path ' ' '"' MIDIPathName MIDIFileName '"' ' -o ' '"' MIDIPathName 'tmpwav.wav' '"'],'-echo');        
        if (~isempty(findstr('not recognized',msg)))
            errordlg(msg);
            disp(msg);
        end
    else
        disp(['fluidsynth -F "' MIDIPathName 'tmpwav.wav" -i -n -T wav /Library/Audio/Sounds/Banks/soundfont.sf2 ' '"' MIDIPathName MIDIFileName '"']);
        [~,msg] = system(['fluidsynth -F "' MIDIPathName 'tmpwav.wav" -i -n -T wav /Library/Audio/Sounds/Banks/soundfont.sf2 ' '"' MIDIPathName MIDIFileName '"'],'-echo');
        if (~isempty(findstr('not recognized',msg)))||(~isempty(findstr('error occurred',msg)))
            errordlg(msg);
            disp(msg);
        end
    end   
    score_nmat = midi2nmat([MIDIPathName MIDIFileName]);
    % Load the MIDI score as audio
    disp([MIDIPathName 'tmpwav.wav']);
    [score, srMIDI] = wavread([MIDIPathName 'tmpwav.wav']);
    score = single(score);
    if(size(score,2)) == 2; score = mean(score')'; end
    % Normalize the waveform
    score = score/max(abs(score));
    % Update the status label
    set(handles.status_label,'String',[MIDIFileName ' loaded with success!'])
    % Delete the temporary wav file
    if ~ismac
        dos(['del ' '"' MIDIPathName 'tmpwav.wav' '"']);
    else
        system(['rm ' '"' MIDIPathName 'tmpwav.wav' '"']);
    end
    set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
    hold on;plot(score,'r');hold off;
    if (AudioFileLoaded)
        % Enable the analysis buttons
        set(handles.analyze_button,'Enable','on')
        set(handles.windowsize_popup,'Enable','on')
        set(handles.feature_popup,'Enable','on')
        set(handles.windowsize_label,'Enable','on')
        set(handles.feature_label,'Enable','on')
        % Update the status label
        set(handles.status_label,'String','Ready for analysis.')
    end
    beep;
end
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error loading score');
end

% --- Executes during object creation, after setting all properties.
function open_panel_CreateFcn(hObject, eventdata, handles)

% --- Executes on button press in clear_button.
function clear_button_Callback(hObject, eventdata, handles)
global reference score exec_path AudioFileLoaded MIDIFileLoaded;
try
set(handles.figure1,'CurrentAxes',handles.waveforms_plot);
cla;
hold on;
if(get(handles.audio_checkbox,'Value')==1) plot(reference); end;
if(get(handles.score_checkbox,'Value')==1) plot(score,'r'); end;
hold off;
axis([1 length(reference) -1 1]);
set(handles.figure1,'CurrentAxes',handles.features_plot1);
cla;
set(handles.figure1,'CurrentAxes',handles.features_plot2);
cla;
set(handles.figure1,'CurrentAxes',handles.simmx_plot);
cla;
% Reset the state of the plotting tools
set(handles.align_button,'Enable','off')
set(handles.svl_label,'Enable','off');
set(handles.svl_checkbox,'Enable','off');
set(handles.distance_label,'Enable','off')
set(handles.searchwidth_label,'Enable','off');
set(handles.distance_popup,'Enable','off')
set(handles.clear_button,'Enable','off')
set(handles.clearplots_button,'Enable','off')
set(handles.listen_button,'Enable','off')
set(handles.savealignment_button,'Enable','off')
set(handles.plottedsignals_label,'Enable','off')
set(handles.featuresplots_label,'Enable','off')
set(handles.score_checkbox,'Enable','off')
set(handles.audio_checkbox,'Enable','off')
set(handles.alignedscore_checkbox,'Enable','off')
set(handles.alignedscore_checkbox,'Value',0.0)
set(handles.plotalignedfeature_checkbox,'Enable','off')
set(handles.plotalignedfeature_checkbox,'Value',0)
set(handles.linkaxes_checkbox,'Enable','off')
set(handles.searchwidth_slider,'Enable','off')
set(handles.stopalignment_button,'Enable','off');
set(handles.linkaxes_checkbox,'Value',0)
set(handles.synthesize_button,'Enable','off');

% Erase the variables
set(handles.status_label,'String','Analysis & alignment cleared.')
clear REF SCOR p q C SM windowsize sr srMIDI alignedscore ASCOR;
pack;
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error during cleanup');
end

% --- Executes on button press in savealignment_button.
function savealignment_button_Callback(hObject, eventdata, handles)
global reference sr AudioFileName AudioPathName aligned_score_nmat exec_path alignedscore srMIDI;
try
if (length(unique(aligned_score_nmat(:,3)))>1)
    multiple_instruments = strcmp('Yes',questdlg([num2str(length(unique(aligned_score_nmat(:,3)))) ' instruments found in the score. Do you want separate files for each instrument?'],'Multiple instruments found','Yes','No','Yes'));
else
    multiple_instruments = 0;
end
[~,file_name,~] = fileparts(AudioFileName);
[OutputFileName,OutputPathName] = uiputfile([AudioPathName file_name '_scorealignment'],'Save alignment...');
if (OutputFileName ~= 0)
    if (multiple_instruments)
        instruments = unique(aligned_score_nmat(:,3));
        for j=1:length(unique(aligned_score_nmat(:,3)))
            fid = fopen([OutputPathName OutputFileName '_instrument' num2str(j) '.txt'],'w');
            for i=1:length(aligned_score_nmat(:,1))
                if (instruments(j)== aligned_score_nmat(i,3))
                    fprintf(fid,'%f ',aligned_score_nmat(i,6));% onset
                    fprintf(fid,'%f ',aligned_score_nmat(i,8));% offset
                    fprintf(fid,'%s\n',char(midi2txt(aligned_score_nmat(i,4))));% note label
                end
            end
            fclose(fid);
        end
    else
        fid = fopen([OutputPathName OutputFileName '.txt'],'w');
        for i=1:length(aligned_score_nmat(:,1))
            fprintf(fid,'%f ',aligned_score_nmat(i,6));% onset
            fprintf(fid,'%f ',aligned_score_nmat(i,8));% offset
            fprintf(fid,'%s\n',char(midi2txt(aligned_score_nmat(i,4))));% note label
        end
        fclose(fid);
    end
    if(get(handles.svl_checkbox,'Value')==1)
        SVLFilename = [OutputFileName '.svl'];
        fid = fopen([OutputPathName SVLFilename],'w');
        fprintf(fid,'<?xml version="1.0" encoding="UTF-8"?>\n');
        fprintf(fid,'<!DOCTYPE sonic-visualiser>\n');
        fprintf(fid,'<sv>\n\t');
        fprintf(fid,'<data>\n\t\t');
        fprintf(fid,'<model id="8" name = "" ' );
        fprintf(fid,'sampleRate="%i" ',sr);
        fprintf(fid,'start="1" ');
        fprintf(fid,'end="%i" ',length(reference));
        fprintf(fid,'type="sparse" dimensions="3" resolution="1" notifyOnAdd="true" dataset="7"  subtype="note" valueQuantization="1" minimum="0" maximum="127" units=""/>\n\t\t');
        fprintf(fid,'<dataset id="7" dimensions="3">\n');
        for i=1:length(aligned_score_nmat(:,1))
            fprintf(fid,'\t\t\t');
            fprintf(fid,'<point frame="%i" ',round(aligned_score_nmat(i,6)*sr));% onset
            fprintf(fid,'value="%i" ',aligned_score_nmat(i,4));% MIDI note
            fprintf(fid,'duration="%i" ',round(aligned_score_nmat(i,7)*sr));% duration
            fprintf(fid,'level="1" ');
            fprintf(fid,'label="%s" ',char(midi2txt(aligned_score_nmat(i,4))));% note label 
            fprintf(fid,'/>\n');
        end
        fprintf(fid,'\t\t</dataset>\n');
        fprintf(fid,'\t</data>\n');
        fprintf(fid,'\t<display>\n');
        fprintf(fid,'\t\t<layer id="25" type="notes" name="Aligned score" model="8"  verticalScale="3" scaleMinimum="0" scaleMaximum="1"  colourName="Bright Orange" colour="#ffbc50" darkBackground="false" />\n');
        fprintf(fid,'\t</display>\n');
        fprintf(fid,'</sv>\n');
        fclose(fid);
    end
end
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error saving the alignment');
end


% --- Executes on button press in listen_button.
function listen_button_Callback(hObject, eventdata, handles)
global reference srMIDI alignedscore player exec_path;
global lineHandle;
try
if (get(hObject,'Value')==1)
    set(hObject,'ForegroundColor','r');
    set(hObject,'String','Stop');
    drawnow;
    player = audioplayer([reference,alignedscore],srMIDI);
    play(player);
    tic;
else
    stop(player);
    set(hObject,'ForegroundColor','k');
    set(hObject,'String','Listen');  
    drawnow;
    if(lineHandle>0) 
        delete(lineHandle); 
        lineHandle = 0;
    end
end
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error during playback');
end

% --- Executes on button press in alignedscore_checkbox.
function alignedscore_checkbox_Callback(hObject, eventdata, handles)
global reference score alignedscore exec_path;
if (length(alignedscore)<=1)
    set(handles.alignedscore_checkbox,'Value',0);
    error('You must synthesize the alignment first!');
end
try
set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
cla;
hold on;
if(get(handles.audio_checkbox,'Value')==1) 
    plot(reference,'b');  
end;
if(get(handles.score_checkbox,'Value')==1) 
    plot(score,'r');
end;
if(length(alignedscore)>1)
    plot(alignedscore,'g'); 
end;
hold off;
axis([1 length(reference) -1 1]);
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error plotting');
end


% --- Executes on button press in audio_checkbox.
function audio_checkbox_Callback(hObject, eventdata, handles)
global reference score alignedscore exec_path;
try
set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
cla;
hold on;
if(get(handles.audio_checkbox,'Value')==1) 
    plot(reference,'b'); 
end;
if(get(handles.score_checkbox,'Value')==1) 
    plot(score,'r');
end;
if(length(alignedscore)>1)
    plot(alignedscore,'g');
end;
hold off;
axis([1 length(reference) -1 1]);
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error plotting');
end

% --- Executes on button press in score_checkbox.
function score_checkbox_Callback(hObject, eventdata, handles)
global reference score alignedscore exec_path;
try
set(handles.figure1,'CurrentAxes',handles.waveforms_plot)
cla;
hold on;
if(get(handles.audio_checkbox,'Value')==1) 
    plot(reference,'b');
end;
if(get(handles.score_checkbox,'Value')==1) 
    plot(score,'r');
end;
if(length(alignedscore)>1)
    plot(alignedscore,'g');
end;
hold off;
axis([1 length(reference) -1 1]);
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error plotting');
end

% --- Executes on button press in plotalignedfeature_checkbox.
function plotalignedfeature_checkbox_Callback(hObject, eventdata, handles)
global REF SCOR windowsize sr srMIDI alignedscore ASCOR exec_path;
try
if(get(hObject,'Value')==1)
    if (length(alignedscore)>1)
        % Calculate and plot em
        if(get(handles.feature_popup,'Value')==1)
            ASCOR = single(abs(specgram(alignedscore,windowsize,srMIDI,windowsize,windowsize/2)));
        else
            ASCOR = single(chromagram_IF(alignedscore,srMIDI,windowsize,12));
        end
        set(handles.figure1,'CurrentAxes',handles.features_plot2);
        imagesc(ASCOR);
        colormap(hot);
        freezeColors;
        if(get(handles.feature_popup,'Value')==1)
            set(handles.features_plot1,'YLim',[0 windowsize/16]);
            set(handles.features_plot2,'YLim',[0 windowsize/16]);
        end
        set(handles.features_plot2,'XTick',get(handles.features_plot1,'XTick'))
        set(handles.features_plot2,'XTickLabel',get(handles.features_plot1,'XTickLabel'))
    else
        set(handles.plotalignedfeature_checkbox,'Value',0);
        error('You must synthesize the alignment first!');
    end
else
    % Plot the old ones
    set(handles.figure1,'CurrentAxes',handles.features_plot1);
    imagesc(REF);
    colormap(hot);
    freezeColors;
    set(handles.figure1,'CurrentAxes',handles.features_plot2);
    imagesc(SCOR);
    colormap(hot);
    freezeColors;
    set(handles.features_plot1,'YTick',[])
    set(handles.features_plot2,'YTick',[])
    if(get(handles.feature_popup,'Value')==1)
        set(handles.features_plot1,'YLim',[0 windowsize/16]);
        set(handles.features_plot2,'YLim',[0 windowsize/16]);
    end
    myXTick1 = get(handles.features_plot1,'XTick');
    for i=1:length(myXTick1);myXTickLabel1{i}=int2str((myXTick1(i)*(windowsize/2))/srMIDI);end;
    myXTick2 = get(handles.features_plot2,'XTick');
    for i=1:length(myXTick2);myXTickLabel2{i}=int2str((myXTick2(i)*(windowsize/2))/srMIDI);end;
    set(handles.features_plot1,'XTickLabel',myXTickLabel1)
    set(handles.features_plot2,'XTickLabel',myXTickLabel2)
end
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error plotting');
end

% --- Executes on button press in linkaxes_checkbox.
function linkaxes_checkbox_Callback(hObject, eventdata, handles)
global REF SCOR windowsize sr srMIDI ASCOR exec_path;
% Hint: get(hObject,'Value') returns toggle state of linkaxes_checkbox
try
if(get(handles.linkaxes_checkbox,'Value')==1)
    linkaxes([handles.features_plot1 handles.features_plot2]);
    myXTick1 = get(handles.features_plot1,'XTick');
    for i=1:length(myXTick1);myXTickLabel1{i}=int2str((myXTick1(i)*(windowsize/2))/srMIDI);end;
    myXTick2 = get(handles.features_plot2,'XTick');
    for i=1:length(myXTick2);myXTickLabel2{i}=int2str((myXTick2(i)*(windowsize/2))/srMIDI);end;
    set(handles.features_plot1,'XTickLabel',myXTickLabel1)
    set(handles.features_plot2,'XTickLabel',myXTickLabel2)
else
    linkaxes([handles.features_plot1 handles.features_plot2],'off');
    set(handles.figure1,'CurrentAxes',handles.features_plot1);
    imagesc(REF);
    colormap(hot);
    freezeColors;
    set(handles.figure1,'CurrentAxes',handles.features_plot2);
    if (length(alignedscore)>1)
        imagesc(ASCOR);
        colormap(hot);      
    else
        imagesc(SCOR);
        colormap(hot);
    end
    freezeColors;
    if(get(handles.feature_popup,'Value')==1)
        set(handles.features_plot1,'YLim',[0 windowsize/16]);
        set(handles.features_plot2,'YLim',[0 windowsize/16]);
    end    
    myXTick1 = get(handles.features_plot1,'XTick');
    for i=1:length(myXTick1);myXTickLabel1{i}=int2str((myXTick1(i)*(windowsize/2))/srMIDI);end;
    myXTick2 = get(handles.features_plot2,'XTick');
    for i=1:length(myXTick2);myXTickLabel2{i}=int2str((myXTick2(i)*(windowsize/2))/srMIDI);end;
    set(handles.features_plot1,'XTickLabel',myXTickLabel1)
    set(handles.features_plot2,'XTickLabel',myXTickLabel2)
end
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error plotting');
end


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function about_menu_Callback(hObject, eventdata, handles)

function uitoggletool1_ClickedCallback(hObject, eventdata, handles)

function uitoggletool5_OnCallback(hObject, eventdata, handles)
h = zoom(handles.figure1);
set(h,'Motion','horizontal');

function uitoggletool3_OnCallback(hObject, eventdata, handles)
h = pan(handles.figure1);
set(h,'Motion','horizontal');

function uipushtool2_ClickedCallback(hObject, eventdata, handles)
abouttext = ['Score Aligner made by Panos Papiotis (panos.papiotis@upf.edu)' sprintf('\n') ...
             'Music Technology Group, Universitat Pompeu Fabra, 2015. ' sprintf('\n\n') ...
             'This program requires MuseScore (musescore.org) in Windows ' ... 
             'and/or Fluidsynth (www.fluidsynth.org) in OSX to synthesize the MIDI files. ' sprintf('\n\n')  ...
             'MIDI files read using the MIDI toolbox by Petri Toiviainen & Tuomas Eerola ' ...
             '(available at https://www.jyu.fi/hum/laitokset/musiikki/en/research/coe/materials/miditoolbox/).' sprintf('\n\n')  ...
             'On-line Time Warping (OLTW) code based on Simon Dixon''s MATCH algorithm' sprintf('\n') ...
             '(see https://code.soundsoftware.ac.uk/projects/match).' sprintf('\n\n') ...
             'Thanks for using!'];
abouttitle = 'About the UPF score aligner';
msgbox(abouttext,abouttitle,'help');

function figure1_CloseRequestFcn(hObject, eventdata, handles)
global exec_path;
try
    clear global;
catch err
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error during shutdown');
end
delete(hObject);

% --- Executes on button press in svl_checkbox.
function svl_checkbox_Callback(hObject, eventdata, handles)

% --- Executes on slider movement.
function searchwidth_slider_Callback(hObject, eventdata, handles)
set(handles.searchwidth_label,'String',['Search width (' num2str(round(get(handles.searchwidth_slider,'Value')*100)) '%)']);

% --- Executes during object creation, after setting all properties.
function searchwidth_slider_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in clearplots_button.
function clearplots_button_Callback(hObject, eventdata, handles)
cla(handles.simmx_plot,'reset');
cla(handles.features_plot1,'reset');
cla(handles.features_plot2,'reset');

% --- Executes on button press in stopalignment_button.
function stopalignment_button_Callback(hObject, eventdata, handles)
global stopalignment;
stopalignment = 1;

% --- Executes on button press in synthesize_button.
function synthesize_button_Callback(hObject, eventdata, handles)
global reference score alignedscore windowsize sr srMIDI p q
try
    watchon;   
    set(handles.status_label,'String','Synthesizing the alignment...');
    drawnow;
    % Create the sound of the aligned MIDI file
    D2 = single(specgram(score,windowsize,srMIDI,windowsize,windowsize/2));
    D1 = single(specgram(reference,windowsize,srMIDI,windowsize,windowsize/2));
    pnew = round(p*(length(D1(1,:))/max(p)));
    qnew = round(q*(length(D2(1,:))/max(q)));
    D2i1 = zeros(1, size(D1,2));
    for i = 1:length(D2i1); D2i1(i) = qnew(find(pnew >= i, 1 )); end
    % Phase-vocoder interpolate D2's STFT under the time warp
    D2i1(D2i1==0) = 1;
    D2x = pvsample(D2, D2i1-1,(windowsize/2));
    % Invert it back to time domain
    d2x = istft(D2x, windowsize, windowsize, (windowsize/2));
    % % Warped version added to original target (have to fine-tune length)
    % This is where Dan Ellis' resize.m function is needed
    alignedscore = single(resizeDE(d2x', length(reference),1));
    set(handles.alignedscore_checkbox,'Enable','on')
    set(handles.plotalignedfeature_checkbox,'Enable','on')
    set(handles.listen_button,'Enable','on')
    set(handles.status_label,'String','Alignment synthesized.')
    watchoff;
catch err
    watchoff;
    curStack = dbstack;     ind = strcmp({err.stack.name},curStack(1).name);     errordlg(['Line ' num2str(err.stack(ind).line) sprintf(':\n') err.message],'Error synthesizing');
end

function RMS = rms(input_signal,window_length,H)
pin = 1;
pend = length(input_signal)-window_length;
RMS = zeros(1,length(input_signal)/H);
i=1;

while pin<pend
    RMS(i) = sqrt(mean(input_signal(pin:pin+window_length).^2));
    pin = pin+H;
    i = i+1;
end

function midilabel = midi2txt(midinum)
noteNames = {['C'];['C#'];['D'];['D#'];['E'];['F'];['F#'];['G'];['G#'];['A'];['A#'];['B']};
midilabel = strcat(noteNames(mod(midinum,12)+1),num2str(floor(midinum/12)-1));
