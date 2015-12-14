function [p,q,CM,SM,sc] = oltw(F1,F2,distance_measure,c,maxRunCount,handle)
% OLTW An implementation of the On-line Time Warping algorithm by
% Simon Dixon (see https://code.soundsoftware.ac.uk/projects/match). 
%
% Reuses elements from Dan Ellis' DTW algorithm (see
% http://labrosa.ee.columbia.edu/matlab/dtw/)
%
% Not a standalone version but rather a companion to score_aligner.m

% A global (unfortunately) variable to halt execution of the function
% externally
global stopalignment;

% A series of transformations to increase the difference between zero
% values and small values
F1 = F1.*1000;
F2 = F2.*1000;
F1(F1==0) = 10^(-10);
F2(F2==0) = 10^(-10);

% Default parameters
if nargin<3
    distance_measure = 'euclidean';
end
if nargin<4
    c = 50;    
end
if nargin<5
    maxRunCount = 5;    
end
if nargin<6
    handle = 0;
end

% Memory allocation
SM = sparse(size(F1,2),size(F2,2));
CM = sparse(size(F1,2),size(F2,2));
steps = sparse(size(F1,2),size(F2,2));

% Internal parameter initialization
t=1;
j=1;
previous = NaN;
runCount = 1;

% Evaluate the cost of the (1,1) element
[CM(t,j) SM(t,j) steps(t,j)] = EvaluatePathCost(t,j,F1,F2,CM,distance_measure);

% A simple counter for the number of times the main loop has been executed
loop_counter = 0;

% Plotting tools for use with an external GUI
if (~isempty(handle))
    curPercent = 0;
    set(handle.figure1,'CurrentAxes',handle.simmx_plot);
    colormap(gray);
    freezeColors;
end

% Main loop
while((t<size(F1,2))||(j<size(F2,2)))
    % Increment the loop counter
    loop_counter = loop_counter+1;
    
    % Choose the optimal direction for the OLTW path (forward calculation)
    currInc = getInc(t,j,previous,c,runCount,maxRunCount,CM);
    
    % Calculate the similarity matrix and cost matrix by advancing the 
    % feature1 sequence by one frame
    if (currInc ~= 1)
        t = t+1;
        for k=j-c+1:j
            if (k>0)
                [CM(t,k) SM(t,k) steps(t,k)] = EvaluatePathCost(t,k,F1,F2,CM,distance_measure);
            end
        end
    end
    
    % Calculate the similarity matrix and cost matrix by advancing the 
    % feature2 sequence by one frame
    if (currInc ~= 0)
        j = j+1;
        for k=t-c+1:t
            if (k>0)
                [CM(k,j) SM(k,j) steps(k,j)] = EvaluatePathCost(k,j,F1,F2,CM,distance_measure);
            end
        end
    end
    
    % Increment the runCount variable if the algorithm advances in the
    % same direction as in the previous step, or reset it if not
    if (currInc == previous)
        runCount = runCount+1;
    else
        runCount = 1;
    end
    
    % Remember the chosen direction in which the algorithm advances for the
    % next iteration
    if (currInc ~= 2)
        previous = currInc;
    end
    
    % Tools for use with an external GUI (plotting the similarity matrix,
    % showing the percentage of completion, breaking computation)
    if (~isempty(handle))
        prevPercent = curPercent;
        curPercent = round((((t/size(F1,2))+(j/size(F2,2)))/2)*100);
        if (curPercent~=prevPercent)
            set(handle.status_label,'String',['Aligning, ' num2str(curPercent) '% done...']);
            imagesc(SM);
            drawnow;
            if stopalignment==1
                stopalignment=0;
                set(handle.status_label,'String','Alignment aborted.');
                set(handle.stopalignment_button,'Enable','off');
                drawnow;
                error('Alignment aborted.');
            end
        end
    end
end

% Backtrack to obtain the optimal alignment path
[p,q,sc] = backtrack(CM,SM,steps);

function Inc = getInc(t,j,previous,c,runCount,maxRunCount,comatrix)
% Choose the optimal direction for the OLTW path (forward calculation)    

% Check if the algorithm has reached the end of one of the sequences and
% increment the other one if so
if (t>=size(comatrix,1))
    Inc = 1;
    return;
elseif (j>=size(comatrix,2))
    Inc = 0;
    return;
end

% Check if the search width has been exhausted at least once; if not,
% increment both sequences
if (t<c)
    Inc = 2;
    return;
end

% Check if we have incremented the same sequence more than maxRunCount times;
% if so, increment the other sequence
if (runCount > maxRunCount)
    if (previous == 0)
        Inc = 1;
        return;
    else
        Inc = 0;
        return;
    end
end

% Find the direction in which the minimum value of the cost matrix lies,
% and increment in that direction
[kVal,k] = min(comatrix(t,j-c+1:j));
[lVal,l] = min(comatrix(t-c+1:t,j));
if kVal < lVal
    Inc = 0;
elseif (kVal==lVal)
    Inc = 2;
else
    Inc = 1;
end



function [cost distance step] = EvaluatePathCost(a,b,feature1,feature2,comatrix,distance_measure)
% Iteratively calculate the similarity matrix and the cost matrix, while
% keeping track of the step chosen for the cost calculation

% Calculate the next cell of the similarity matrix 
if (strcmp(distance_measure,'cosine'))
    distance = 1-(sum((feature1(:,a).*feature2(:,b)))/(sqrt(sum(feature1(:,a).^2))*sqrt(sum(feature2(:,b).^2))));
else
    distance = norm(feature1(:,a)-feature2(:,b));
end

% Avoid zero distance values
if (distance==0)
    distance = 10^(-100);
end

% Calculate the next cell of the cost matrix
if ((a==1)&&(b==1)) % i.e. if it's the (1,1) cell
    cost = 1;
    step = 0;
else
    try
        % Evaluate the cost of C(i,j-1)+distance
        step1 = (full(comatrix(a,b-1))+distance);
        if (step1==distance)
            % Do not consider cells with a cost of zero
            step1 = Inf;
        end
    catch err
        step1 = Inf;
    end

    try
        % Evaluate the cost of C(i-1,j)+distance
        step2 = (full(comatrix(a-1,b))+distance);
        if (step2==distance)
            % Do not consider cells with a cost of zero
            step2 = Inf;
        end
    catch err
        step2 = Inf;
    end

    try
        % Evaluate the cost of C(i-1,j-1)+distance
        step3 = (full(comatrix(a-1,b-1))+distance);
        if (step3==distance)
            % Do not consider cells with a cost of zero
            step3 = Inf;
        end
    catch err
        step3 = Inf;
    end
    
    % Find the minimum cost from all three possible steps
    if (strcmp(distance_measure,'cosine'))
        [cost,step] = min([step1 step2 step3]); 
    else
        [cost,step] = min([step1 step2 step3]);
    end
end

function [p,q,sc] = backtrack(comatrix,simatrix,steps)

C = [0 1 1;1 0 1;1 1 1];
[r,c] = size(comatrix);
if min(size(comatrix)) == 1
    % degenerate D has only one row or one column - messes up diag
    i = r;
    j = c;
else
    % Traceback from min of antidiagonal
    %stepback = floor(0.1*c);
    stepback = 1;
    slice = diag(fliplr(comatrix),-(r-stepback));
    [~,ii] = min(slice);
    i = r - stepback + ii;
    j = c + 1 - ii;
end

p=i;
q=j;
sc = simatrix(p,q);

while i > 1 & j > 1
    %  disp(['i=',num2str(i),' j=',num2str(j)]);
    tb = steps(i,j);
    i = i - C(tb,1);
    j = j - C(tb,2);
    p = [i,p];
    q = [j,q];
    sc = [simatrix(i,j),sc];
end
