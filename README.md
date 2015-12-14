# scorealigner

A simple audio-to-midi score alignment program in MATLAB, with a helpful GUI.

This software reads an audio file (in .wav and .mp3 format for windows, .wav for OSX) as well as a MIDI score and computes a temporal alignment between the two using my own implementation of [Simon Dixon's On-line Time Warping (OLTW) algorithm](https://code.soundsoftware.ac.uk/projects/match).

MIDI synthesizer dependencies:
* [Musescore](https://musescore.org) (for Windows), or 
* [Fluidsynth](www.fluidsynth.org) (for OSX). In case Fluidsynth is used, the user needs to place a GM SoundFont file ([some free nice ones can be found here](https://musescore.org/en/handbook/soundfont)) in `/Library/Audio/Sounds/Banks/soundfont.sf2`

MATLAB dependencies
* the [freezeColors](http://es.mathworks.com/matlabcentral/fileexchange/7943-freezecolors---unfreezecolors) MATLAB library for using multiple colormaps per figure in the GUI
* Dan Ellis' [Chromagram_IF](http://www.ee.columbia.edu/~dpwe/resources/matlab/chroma-ansyn/) function for computing chromagrams from audio
* Dan Ellis' [pvsample, istft](http://www.ee.columbia.edu/~dpwe/resources/matlab/pvoc/) and [resize](http://www.ee.columbia.edu/ln/rosa/matlab/dtw/resize.m) functions for timestretching the aligned score audio
* Petri Toiviainen an Tuomas Eerola's [MIDI Toolbox (and more specifically the midi2nmat.m function)](https://www.jyu.fi/hum/laitokset/musiikki/en/research/coe/materials/miditoolbox) for extracting note onset and offset information from MIDI files
