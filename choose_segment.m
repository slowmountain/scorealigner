function varargout = choose_segment(varargin)
% CHOOSE_SEGMENT small chunk of code used to select a segment of a larger
% recording.

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @choose_segment_OpeningFcn, ...
                   'gui_OutputFcn',  @choose_segment_OutputFcn, ...
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


% --- Executes just before choose_segment is made visible.
function choose_segment_OpeningFcn(hObject, eventdata, handles, varargin)
global reference;
% Choose default command line output for choose_segment
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
plot(reference);

% --- Outputs from this function are returned to the command line.
function varargout = choose_segment_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;


% --- Executes on button press in donebutton.
function donebutton_Callback(hObject, eventdata, handles)
global startSample endSample reference
xlimits = xlim(handles.choosesegment_axes);
startSample = max(xlimits(1),1);
endSample = min(xlimits(2),length(reference));
close;

function uitoggletool4_OnCallback(hObject, eventdata, handles)
h = zoom(handles.choosesegment_axes);
set(h,'Motion','horizontal');

function uitoggletool5_OnCallback(hObject, eventdata, handles)
h = zoom(handles.choosesegment_axes);
set(h,'Motion','horizontal');

function uitoggletool8_OnCallback(hObject, eventdata, handles)
h = pan(handles.figure1);
set(h,'Motion','horizontal');