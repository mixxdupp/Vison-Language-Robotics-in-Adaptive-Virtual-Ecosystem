clc;
clear all;
close all;
name = "Matlab";
Client = TCPInit('127.0.0.1', 55001, name);

% --- Robot Definition and Initial Setup (Unchanged) ---
% gripping_point = 0.056;
gripping_point = 0.1978;

L(1) = Revolute('d', 0.2358, 'a', 0, 'alpha', -pi/2);
L(2) = Revolute('d', 0, 'a', 0.3187, 'alpha', -pi);
L(3) = Revolute('d', 0, 'a', 0.0735, 'alpha', -pi/2);
L(4) = Revolute('d', -0.25, 'a', 0, 'alpha', pi/2);
L(5) = Revolute('d', 0, 'a', 0, 'alpha', -pi/2);
L(6) = Revolute('d', -gripping_point, 'a', 0, 'alpha', pi);
robot = SerialLink(L);
initial_joints = [0, -pi/2, 0, 0, -pi/2, 0]; % Store initial pose

% --- Define Tile Coordinates (Unchanged) ---
tile_coords = struct();
tile_coords.red = struct('X', 0.44136, 'Y', -0.064, 'Z', 0.087 + 0.08);
tile_coords.green = struct('X', 0.44136, 'Y', -0.2083, 'Z', 0.087 + 0.12);
tile_coords.blue = struct('X', 0.3027599, 'Y', -0.2083, 'Z', 0.087 + 0.2);

t = [0:0.1:2]; % Trajectory time steps

% --- Python Integration Setup ---
% !! IMPORTANT: Update these paths !!
pythonExecutable = 'python'; % Or full path like 'C:/Users/YourUser/AppData/Local/Programs/Python/Python39/python.exe'
scriptPath = ''; % Set to 'path/to/your/scripts/' if they are not in the current MATLAB directory. Include trailing slash/backslash.
speakScript = [scriptPath, 'speak_text.py'];
listenScript = [scriptPath, 'listen_for_command.py'];

% Helper function for speaking
speak = @(text) system(sprintf('%s "%s" "%s"', pythonExecutable, speakScript, text));
% Helper function for listening
listen = @() system(sprintf('%s "%s"', pythonExecutable, listenScript));


% --- Main Loop ---
for i = 1:3

    fprintf('--- Starting Cycle %d ---\n', i);

    % --- Move to Pick Up Location (Unchanged) ---
    grab = 2; % Ensure EE is not grabbing/releasing initially
    X0 = 0.427; Y0 = 0.241; Z0 = 0.2;
    T_pickup_approach = transl(X0, -Y0, Z0) * trotx(180, "deg");
    q_pickup_approach = robot.ikine(T_pickup_approach, 'q0', initial_joints, 'mask', [1 1 1 1 1 1]);
    q_traj_to_pickup = jtraj(initial_joints, q_pickup_approach, t);
    b = 1; for a = 1:length(q_traj_to_pickup); func_data(Client, q_traj_to_pickup, b); b = b + 1; end
    pause(0.5);

    % --- GRABING THE OBJECT (Unchanged) ---
    grab = 1; func_grab(Client, grab);
    fprintf('Sent GRAB command.\n');
    pause(4.5);

    % Generate the *next* Cube (Adjusted for demo)
    if (i == 1); init = 1; fprintf('Requesting RED cube generation.\n');
    elseif (i == 2); init = 2; fprintf('Requesting GREEN cube generation.\n');
    else; init = 3; fprintf('Requesting BLUE cube generation.\n');
    end
    new_object(Client, init);
    pause(1);

    % --- Move Back from Pickup (Unchanged) ---
    q_traj_from_pickup = jtraj(q_pickup_approach, initial_joints, t);
    b = 1; for a = 1:length(q_traj_from_pickup); func_data(Client, q_traj_from_pickup, b); b = b + 1; end
    current_joints = initial_joints;
    fprintf('Returned to initial pose with cube.\n');

    % --- Move to Color Check / Camera Position (Unchanged) ---
    X1 = 0.303; Y1 = -0.064; Z1 = 0.2;
    T_camera = transl(X1, -Y1, Z1) * trotx(180, "deg");
    q_camera = robot.ikine(T_camera, 'q0', current_joints, 'mask', [1 1 1 1 1 1]);
    q_traj_to_camera = jtraj(current_joints, q_camera, t);
    b = 1; for a = 1:length(q_traj_to_camera); func_data(Client, q_traj_to_camera, b); b = b + 1; end
    current_joints = q_camera;
    fprintf('Moved cube to camera position.\n');
    pause(1.0);

    % --- COLOR CHECK (Unchanged Function Call) ---
    fprintf('Requesting color check...\n');
    color = color_check(Client);
    fprintf('Color check complete.\n');

    % ==============================================================
    % --- MODIFICATION START: Voice Control Interaction ---
    % ==============================================================

    % 1. Announce Detected Color (TTS)
    color_name = '';
    if color == 1; color_name = 'Red';
    elseif color == 2; color_name = 'Green';
    else; color_name = 'Blue';
         if color ~= 3; warning('color_check returned unexpected value %d, assuming Blue.', color); end
    end

    fprintf('\n--- Voice Interaction ---\n');
    speak(sprintf('Detected %s Cube.', color_name)); % Speak detected color

    % 2. Ask for Target Tile (TTS) and Get User Input (STT)
    validInput = false;
    target_X = 0; target_Y = 0; target_Z = 0; % Initialize target coords
    maxAttempts = 3; % Limit number of listening attempts
    attempt = 0;

    while ~validInput && attempt < maxAttempts
        attempt = attempt + 1;
        fprintf('Attempt %d/%d to listen...\n', attempt, maxAttempts);
        speak('Which Tile: Red, Green, or Blue, do you want to place it on?'); % Ask the question

        % ** STT via Python Script **
        [status, recognizedText] = listen(); % Call the Python listening script

        % Clean up the captured text (remove potential newlines etc.)
        recognizedText = strtrim(recognizedText);
        fprintf('Heard: "%s" (Status: %d)\n', recognizedText, status);

        % Check status and output
        if status == 0 && ~isempty(recognizedText) && ~contains(recognizedText, ["ERROR:", "TIMEOUT:"])
            % 3. Parse Command and Map to Coordinates
            userInputLower = lower(recognizedText);

            if contains(userInputLower, 'red')
                target_X = tile_coords.red.X; target_Y = tile_coords.red.Y; target_Z = tile_coords.red.Z;
                fprintf('Command recognized: Placing on RED tile.\n');
                speak('Okay, placing on the Red tile.'); % Confirmation TTS
                validInput = true;
            elseif contains(userInputLower, 'green')
                target_X = tile_coords.green.X; target_Y = tile_coords.green.Y; target_Z = tile_coords.green.Z;
                fprintf('Command recognized: Placing on GREEN tile.\n');
                speak('Okay, placing on the Green tile.'); % Confirmation TTS
                validInput = true;
            elseif contains(userInputLower, 'blue')
                target_X = tile_coords.blue.X; target_Y = tile_coords.blue.Y; target_Z = tile_coords.blue.Z;
                fprintf('Command recognized: Placing on BLUE tile.\n');
                speak('Okay, placing on the Blue tile.'); % Confirmation TTS
                validInput = true;
            else
                fprintf('Input "%s" not matched to a tile.\n', recognizedText);
                if attempt < maxAttempts
                   speak('Sorry, I did not understand that. Please say Red, Green, or Blue.');
                end
            end
        else
             fprintf('Speech recognition failed or timed out (Status: %d, Output: %s).\n', status, recognizedText);
             if attempt < maxAttempts
                 if contains(recognizedText, 'TIMEOUT')
                     speak('I did not hear anything. Please speak clearly after the prompt.');
                 else
                     speak('Sorry, I could not understand. Please try again.');
                 end
             end
        end % End status/output check

        if ~validInput && attempt < maxAttempts
            pause(0.5); % Short pause before asking again
        end

    end % End while loop

    % Handle case where input was never valid after max attempts
    if ~validInput
        fprintf('Max listening attempts reached. Could not get valid command.\n');
        speak('Sorry, I could not get a valid command after several tries. Skipping placement for this cube.');
        % Optional: Decide what to do - e.g., drop cube, return home, stop script
        % For now, we'll just skip the placement and go back home.
        fprintf('Returning to initial pose without placing cube...\n');
        q_traj_to_initial = jtraj(current_joints, initial_joints, t);
        b = 1; for a = 1:length(q_traj_to_initial); func_data(Client, q_traj_to_initial, b); b = b + 1; end
        current_joints = initial_joints;
        fprintf('Returned to initial pose. Cycle %d aborted.\n\n', i);
        pause(1.0);
        continue; % Skip to the next iteration of the main loop
    end

    % ============================================================
    % --- END OF MODIFICATION ---
    % ============================================================

    pause(0.5); % Pause after interaction

    % --- PLACING THE CUBE TO THE USER-SPECIFIED PLACE ---

    % 4. Move to Target Tile (Using coordinates determined from voice input)
    fprintf('Calculating trajectory to target tile...\n');
    T_place = transl(target_X, -target_Y, target_Z) * trotx(180, "deg");
    q_place = robot.ikine(T_place, 'q0', current_joints, 'mask', [1 1 1 1 1 1]);

    q_traj_to_place = jtraj(current_joints, q_place, t);
    b = 1; for a = 1:length(q_traj_to_place); func_data(Client, q_traj_to_place, b); b = b + 1; end
    current_joints = q_place;
    fprintf('Moved cube to target tile.\n');

    % 5. Release Object
    grab = 0; func_grab(Client, grab);
    fprintf('Sent RELEASE command.\n');
    pause(2.5);

    % --- Back to initial pos (Unchanged) ---
    fprintf('Returning to initial pose...\n');
    q_traj_to_initial = jtraj(current_joints, initial_joints, t);
    b = 1; for a = 1:length(q_traj_to_initial); func_data(Client, q_traj_to_initial, b); b = b + 1; end
    current_joints = initial_joints;
    fprintf('Returned to initial pose. Cycle %d complete.\n\n', i);
    pause(1.0);

end % End of for loop

%Close Gracefully
fprintf(1, "Disconnecting from server...\n");
speak('Task finished. Disconnecting.');
pause(1); % Allow TTS to finish
% Consider explicitly closing the TCP client if needed
% fclose(Client);
fprintf(1, "Disconnected.\n");