% Omit all params to run as test/debug.
% Enter just subject numbers to record into a datafile
% with the subjects' numbers, using default size of grid relative to screen
% height (90%) and default number of gridSquares (5).
% Otherwise can also use last two params to see what other sizes/grid
% configurations may be desirable. 
function TreasureMapEEG(subject1Number,subject2Number,gridSquaresAcross,sHeightPercent)
% Screen('Preference', 'SkipSyncTests', 1); % (For testing on my occasionally fussy
% Windows setup.)
try
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Basic PsychtoolBox Program Setup %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    AssertOpenGL; % Check OpenGL compatibility
    rand('state',sum(100*clock)); %Seed the random number generator
    
    screenNumber = max(Screen('Screens'));
    [wPtr, wRect] = Screen('OpenWindow',screenNumber,0,[],32,2);
    Screen('BlendFunction', wPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); %Anti aliasing, So that we can draw circular dots

    
    Screen('TextFont',wPtr,'Courier New');
    
    fontsize = 25; % used in later text coordinate calculation, can be adjusted freely
    
    Screen('TextSize',wPtr,fontsize);
    Screen('TextStyle',wPtr,1);
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Arguments / Constants / Data Output File Setup %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if (nargin == 0) %All defaults
        datafilename = 'TreasureGridEEG_999.dat';
    else
        datafilename = strcat('TreasureGridEEG_',num2str(subject1Number),'_',num2str(subject2Number),'.dat');
    end
    if ~exist('gridSquaresAcross','var'), gridSquaresAcross = 5; end
    if ~exist('sHeightPercent','var'), sHeightPercent = .9; end
    
    if(nargin ~= 0 && fopen(datafilename, 'rt')~=-1)
        fclose('all');
        error('Result data file already exists! Choose a different subject number.');
    else
        datafilepointer = fopen(datafilename,'wt'); % open file for writing
    end
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Setting up Player / Turn / Score Data %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    currentPlayer = 0;
    player0Hits = 0;
    player1Hits = 0;
    currentTurn = 1;
    
    %Preallocating matrices for performance
    gridStateData = zeros(gridSquaresAcross); % Record of untouched, treasure, or empty gridspaces
                                            % Untouched spaces are 0s,
                                            % treasure 1s, misses 2s
    treasureDrawCoords = zeros(2,(gridSquaresAcross*gridSquaresAcross)); % Coordinates where found treasure markers are drawn
    treasureDrawCoordsIndex = 1; % Used for efficiently updating above preallocated matrix at correct spot
    
    missDrawCoords = zeros(2,(gridSquaresAcross*gridSquaresAcross)); % Coordinates where "empty/miss" markers are drawn
    missDrawCoordsIndex = 1;
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Calculating x,y array for DrawLines to draw Grid %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    numLines = gridSquaresAcross + 1;
    maxx = wRect(3); %max x of current resolution 
    maxy = wRect(4);

    fullGridSideLength = round(maxy * sHeightPercent);

    ysidedist = ((maxy - fullGridSideLength) / 2); % Distance between top of screen and top of grid
    xsidedist = ((maxx - fullGridSideLength) / 2); % Distance between side of screen and side of grid
    
    gridMinX = xsidedist; 
    gridMinY = ysidedist;
    gridMaxY = maxy - ysidedist;
    gridMaxX = maxx - xsidedist;
    
    xyhoriztoprow = zeros(1,numLines*2);
    xyhorizbottomrow = repmat([gridMinY,gridMaxY],1,numLines);
    xyverticaltoprow = repmat([gridMinX,gridMaxX],1,numLines);
    xyverticalbottomrow = zeros(1,numLines*2);
    spacing = fullGridSideLength / gridSquaresAcross;
    for i = 1:numLines
       xhorizval = gridMinX + ((i - 1) * spacing);
       yvertval = gridMinY + ((i - 1) * spacing);
       
       cord2 = i*2; cord1 = cord2 - 1;
       xyhoriztoprow(cord1) = xhorizval;
       xyhoriztoprow(cord2) = xhorizval;
       xyverticalbottomrow(cord1) = yvertval;
       xyverticalbottomrow(cord2) = yvertval;
    end
    
    linecoords = [xyhoriztoprow, xyverticaltoprow; xyhorizbottomrow, xyverticalbottomrow];
    
    % Calculate dot size for markers
    % 60% of the grid space (max 63px) is used as the dotsize unless that results
        % in an error, in which case a 10-pixel width dot
        % is used (arbitrary, but the common upper limit for older
        % gfx-cards.)
    dotsize = min(floor((spacing * .6)),63);
    try
        Screen('DrawDots',wPtr,[-30;-30],dotsize,[255, 255, 255, 255]);
    catch
        dotsize = 10;
    end
    
     try
        Priority(9); %Enable real-time scheduling for actual trial
     catch
        try
            Priority(2);
        catch
        end
    end
    
    vbl = Screen('Flip',wPtr); %Initially sync with retrace.
    while(1)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Draw main grid, treasure / miss markers, and text for usual gameplay screen. %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        Screen('DrawLines',wPtr,linecoords,4); %Grid being drawn
       
        if(missDrawCoordsIndex > 1) %Check whether there is anything to draw yet in this matrix
            Screen('DrawDots',wPtr,missDrawCoords(:,1:missDrawCoordsIndex-1),dotsize,[255, 255, 255, 255]);
                                    %^ Only draw what's been filled in, not
                                    %  the 0,0s from preallocation
        end
        if(treasureDrawCoordsIndex > 1)
            Screen('DrawDots',wPtr,treasureDrawCoords(:,1:treasureDrawCoordsIndex-1),dotsize,[255, 255, 255, 255],[0 0],2);
        end
        
        % Drawing player's score / turn text
        if(currentPlayer == 0) % Player 0 will be the top half ('across') the screen.
            turnTextX = gridMaxX + xsidedist - (fontsize * 8);
            turnTextY = gridMinY - ysidedist + (fontsize * 4);
            flipText = 1;
        else
            turnTextX = gridMinX - xsidedist + fontsize;
            turnTextY = gridMaxY + ysidedist - (fontsize * 6);
            flipText = 0;
        end
        
        if(currentTurn < gridSquaresAcross^2 + 1)
            DrawFormattedText(wPtr,'Your Turn',turnTextX,turnTextY,[255, 255, 255, 255], ...
            [],flipText,flipText);
        end
        
        DrawFormattedText(wPtr,sprintf('HITS: %i \n\nPlayer 0',player0Hits),gridMaxX + xsidedist - (fontsize * 8),...
            gridMinY - ysidedist + (fontsize * 1),[255, 255, 255, 255], ...
            [],1,1);
        DrawFormattedText(wPtr,sprintf('Player 1\n\nHITS: %i',player1Hits),gridMinX - xsidedist + fontsize,...
           gridMaxY + ysidedist - (fontsize * 5),[255, 255, 255, 255]);
        
        
        Screen('DrawingFinished', wPtr);
        
        % This is where the usual grid appears if that timestamp is wanted.
        Screen('Flip',wPtr);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Check if all grids have been taken and game is finished.. %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        if(currentTurn >= gridSquaresAcross^2 + 1) % Game over, all gridspaces have been selected.
            WaitSecs(1); % Show completed grid for a moment
            Screen('Flip',wPtr); % Clear screen...
            WaitSecs(1); % Blank screen for a moment
            
            % Results screen
            if(player1Hits > player0Hits)
                winText = 'Player 1 wins!';
            elseif(player1Hits < player0Hits)
                winText = 'Player 0 wins!';
            else
                winText = 'Tie!';
            end
            
            Screen('DrawText', wPtr, winText, ...
                wRect(3)/2, wRect(4)/2, [255, 255, 255, 255]);
            Screen('DrawingFinished', wPtr);
            vbl = Screen('Flip',wPtr); % Show win results text
            
            %Recording 'saw game over results' to file.
            % Data format, by columns:
            %1 - turn#
            %2 - timestamp 
            %3 - currentActingPlayer (Player who just clicked, not really relevant on game over)
            %4 - foundTreasureOrNot (a.k.a. 1 = hit, 0 = miss)
            %5 - P0Score
            %6 - P1Score,
            %7 - eventType (currently 'turn' or 'gameOver')
            %[ 8 / 9 - EEGData?]
            eventType = 'gameOver';
                fprintf(datafilepointer, '%i %i %i %i %i %i %s\n', ...
                                           currentTurn, ...
                                           vbl, ... 
                                           currentPlayer, ...
                                           abs(gridStateData(indx,indy) - 2), ... %Converts 2 of miss into 0 (false) or 1 for hit into 1 (true)
                                           player0Hits, ...
                                           player1Hits, ...
                                           eventType); % EEG data for both players can be inserted at the end.
            
            WaitSecs(2);
            Screen('CloseAll'); % Exit
            fclose('all');
            Priority(0);
            return;
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Else, standard turn, showing grid screen %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        [~,mx,my,~] = GetClicks(wPtr,0);
        
        if(IsInRect(mx,my,[gridMinX, gridMinY, gridMaxX, gridMaxY]))
            
           % Conversion of the mouse x,y to corresponding indices in gridStateData
           indx = floor((mx - gridMinX) / spacing) + 1;
           indy = floor((my - gridMinY) / spacing) + 1;

            if(gridStateData(indx,indy) == 0) % Clicked on an untouched grid 
                
                %%%%%%%%%%%%%%%%&&%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Deciding whether or not click results in a treasure hit %
                %%%%%%%%%%%%%%%%%%&&%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    treasureChance = rand;
                    hitThreshhold = .5; % Default hit/miss chance is 50%.
                    
                    currentlyLowerPlayer = ...
                         (currentPlayer == 0 && player0Hits < player1Hits) || ...
                         (currentPlayer == 1 && player0Hits > player1Hits);
                    
                    gridsLeft = (gridSquaresAcross ^ 2) - currentTurn - 1;
                    
                    
                    %If there is a score difference of 3 or more, hit
                    %chances are 75% for lower player and 25% for higher
                    %player
                    if(abs(player1Hits - player0Hits) >= 3)
                      if(currentlyLowerPlayer)
                        hitThreshhold = .25;
                      else
                        hitThreshhold = .75;
                      end
                    end
                    
                    % In situations where it would be impossible
                    % for the lower player to win unless they hit now or 
                    % the higher player misses, ensure that hit or miss occurs.
                    % (example: 2 spaces left, currently p1's turn,
                    %   scores: p1 - 1, p2 - 2; if p1 misses, guaranteed
                    %   loss. This ensures the 'winner' is not known
                    %   until the last turn.
                    if(abs(player1Hits - player0Hits) >= (gridsLeft/2))
                        if(currentlyLowerPlayer) 
                            hitThreshhold = 0;
                        else
                            hitThreshold = 1;
                        end
                    end
                    
                    % If it's the last turn, it's just the usual 50%.
                    if(gridsLeft == 1), hitThreshold = .5; end
    
                    
                    if(treasureChance > hitThreshhold)
                        gridStateData(indx,indy) = 1;
                    elseif(treasureChance < hitThreshhold)
                        gridStateData(indx,indy) = 2;
                    end
                    
                    
                % If treasure was found, update treasure marker drawing
                % coordinates.
                if(gridStateData(indx,indy) == 1)

                    treasureDrawCoords(1,treasureDrawCoordsIndex) = round(gridMinX + ((indx - 1) * spacing) + (spacing / 2));
                    treasureDrawCoords(2,treasureDrawCoordsIndex) = round(gridMinY + ((indy - 1) * spacing) + (spacing / 2));
                    treasureDrawCoordsIndex = treasureDrawCoordsIndex + 1;

                    
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Displaying "treasure found" screen %
                %%%%%%%%%%%%%%%%%%&&%%%%%%%%%%%%%%%%%%
                    
                     Screen('Flip',wPtr);
                     WaitSecs(.7);
                     Screen('FillOval',wPtr,[255 255 255 255],[gridMinX, gridMinY, gridMaxX, gridMaxY]);
                     vbl = Screen('Flip',wPtr);
                     WaitSecs(.7);
                     Screen('Flip',wPtr);
                     WaitSecs(.7);

                    if(currentPlayer == 0)
                        player0Hits = player0Hits + 1;
                    elseif (currentPlayer == 1)
                        player1Hits = player1Hits + 1;
                    end

                end
                %If click was a miss, update miss marker drawing
                %coordinates.
                if(gridStateData(indx,indy) == 2)

                    missDrawCoords(1,missDrawCoordsIndex) = round(gridMinX + ((indx - 1) * spacing) + (spacing / 2));
                    missDrawCoords(2,missDrawCoordsIndex) = round(gridMinY + ((indy - 1) * spacing) + (spacing / 2));
                    missDrawCoordsIndex = missDrawCoordsIndex + 1;

                    
                    
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Displaying "no treasure found" screen %
                %%%%%%%%%%%%%%%%%%&&%%%%%%%%%%%%%%%%%%%%%
                    
                     Screen('Flip',wPtr);
                     WaitSecs(.7);
                     Screen('FillRect',wPtr,[255 255 255 255],[gridMinX, gridMinY, gridMaxX, gridMaxY]);
                     vbl = Screen('Flip',wPtr);
                     WaitSecs(.7);
                     Screen('Flip',wPtr);
                     WaitSecs(.7);
                end

                % Recording this turn's data
                eventType = 'turn';
                fprintf(datafilepointer, '%i %i %i %i %i %i %s\n', ...
                                           currentTurn, ...
                                           vbl, ... 
                                           currentPlayer, ...
                                           abs(gridStateData(indx,indy) - 2), ... %Converts 2 of miss into 0 (false) or 1 for hit into 1 (true)
                                           player0Hits, ...
                                           player1Hits, ... 
                                           eventType); % EEG data for both players can be inserted at the end.
                % Data format explained on 'Data format, by columns:' line
                % earlier in file


                currentPlayer = ~currentPlayer;
                currentTurn = currentTurn + 1;

                    
                end

            end
       
    end

    
catch
    psychrethrow(psychlasterror);
    fprintf(datafilepointer, 'Terminated with error');
    fclose('all');
    Screen('CloseAll');
    Priority(0);
    ShowCursor;
end;

end
