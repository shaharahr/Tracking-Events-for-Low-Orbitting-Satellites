function [out, names] = interceptPairs(masterNum, filename)
    tic
    %start timer
    
    ca = readcell(filename);
    %input sorted data file as a cell array
    out = [];

    nameBase = ca(1,1:4:end);
    %take first row and the names of all the satellites
    [~,ln] = size(nameBase);
    names = [];
    parfor y = 1:ln
        sat = regexp(nameBase{y}, 'to Satellite/', 'split');
        %splites each names like 'Facility/Asc_Island to
        %Satellite/SPOT_6_38755' into {'Facility/Asc_Island to
        %Satellite/'} {'SPOT_6_38755'}
        sat = sat(2);
        names = [names; sat];
        %puts all of the satellite names into a vertical cell array
    end
    timeBase = ca(:,2:4:end);
    %creates new cell array consisting of all of the time columns of each
    %satellite
    [rowt,colt] = size(timeBase);
    time = [];
    %time in seconds as a double
    plotTime = [];
    %time as MM/DD/YYYY etc. as a datetime
    parfor a = 1:rowt
        newRow = [];
        otherRow = []
        for b = 1:colt
            if timeBase{a,b} < '21-May-2024 00:00:00'
                timeBase{a,b} = datetime('21-May-2024  00:00:00');
                %the cell array has filler inputs to ensure that the cell
                %array is a rectangle without any gaps, so some of the
                %date inputs are '0'
                %this turns the '0' into '21-May-2024 00:00:00 so they can
                %be altered later and ignored
            end
            otherRow = [otherRow, datetime(timeBase{a,b})];
            timeBase{a,b} = seconds(timeBase{a,b} - '21-May-2024 00:00:00');
            %turns datetime into seconds as a double so I can find the
            %intercepts later
            newRow = [newRow, timeBase{a,b}];
        end
        time = [time; newRow];
        plotTime = [plotTime; otherRow];
    end
    azimuthBase = cell2mat(ca(:,3:4:end));
    %all azimuth columns
    elevationBase = cell2mat(ca(:,4:4:end));
    %all elevation columns
    disp('Base created')

    timeMast = time(:,masterNum);
    %the time column for the 'master' satellite
    azimuthMast = azimuthBase(:,masterNum);
    %azimuth column for master satellite
    elevationMast = elevationBase(:,masterNum);
    %elevation column for master satellite
    zeroMast = azimuthMast == 0;
    timeMast(zeroMast) = [];
    azimuthMast(zeroMast) = [];
    elevationMast(zeroMast) = [];
    %deletes all filler rows so they won't be plotted
    lMast = length(timeMast);
    disp('Master created, figure loop started!')
    
    for j = 1:colt
        %loop of each individual satellite, the temporary one to be
        %compared against the master satellite
        if j == masterNum
            out = [out; '--'];
            continue
        end
        %prevents plotting the master satellite against itself

        timeTemp = time(:,j);
        %time in seconds
        timeBaseTemp = plotTime(:,j);
        %time in the MM/DD/YYYY datetime
        azimuthTemp = azimuthBase(:,j);
        elevationTemp = elevationBase(:,j);
        %data for the temporary satellite 
        zeroTemp = azimuthTemp == 0;
        timeTemp(zeroTemp) = [];
        timeBaseTemp(zeroTemp) = [];
        azimuthTemp(zeroTemp) = [];
        elevationTemp(zeroTemp) = [];
        %deletes all filler rows so they wont be plotted
        l = length(timeTemp);
        inter = 0;

        holder = 1;
        %initialize the start of the plotting
        f = figure();
        %so the figure wont pop up and stop the HPC from running in the
        %b

        for i = 2:l
            %for each row, or data point
            if timeTemp(i) - timeTemp(i-1) >= 1800
                %if the difference between two time points is greater than
                %1800 seconds, or 30 minutes, separate them and plot the
                %first section, which is the holder to point i
                %I could probably change it to be a shorter time period,
                %maybe 10 minutes, I just figures 30 minutes was an alright
                %range since most of the gaps were greater than an hour, will test it out later though
                subplot(2,1,1)
                hold on
                plot(timeBaseTemp(holder:i-1),azimuthTemp(holder:i-1), 'b', 'DisplayName', names{j})
                %plot azimuth of temporary satellite

                subplot(2,1,2)
                hold on
                plot(timeBaseTemp(holder:i-1),elevationTemp(holder:i-1), 'b', 'DisplayName', names{j})
                %plot elevation of temporary satellite

                [~,idi] = min(abs(timeMast-timeTemp(holder)));
                %finds the index of the start of where temporary satellite and
                %master satellite may be tracked together, where they are
                %plotted in the same area and have the possibility of
                %intersecting
                if idi+1 <= lMast && timeMast(idi) - timeMast(idi+1) < 20
                    %first statement makes sure not to index out
                    %second statement makes sure that the indexed point
                    %isn't on the 'edge' of the section of time, that there
                    %won't be any 'jumps'
                    p=0;

                    %finds and indexes the edge(end) of the master dataset to
                    %create the section within the same time frame that can
                    %be compared to the temporary satellite section


                    while idi+p+1 <= lMast && timeMast(idi+p+1)-timeMast(idi+p) < 20
                        p = p+1;
                    end
                    [t1,a1] = polyxpoly(timeTemp(holder:i-1),azimuthTemp(holder:i-1),timeMast(idi:idi+p),(azimuthMast(idi:idi+p))+1);
                    [t2,a2] = polyxpoly(timeTemp(holder:i-1),azimuthTemp(holder:i-1),timeMast(idi:idi+p),(azimuthMast(idi:idi+p))-1);
                    [t3,e1] = polyxpoly(timeTemp(holder:i-1),elevationTemp(holder:i-1),timeMast(idi:idi+p),(elevationMast(idi:idi+p))+1);
                    [t4,e2] = polyxpoly(timeTemp(holder:i-1),elevationTemp(holder:i-1),timeMast(idi:idi+p),(elevationMast(idi:idi+p))-1);
                    %using the polyxpoly function, find intersections in
                    %the azimuth and elevation of both the temporary and
                    %master with a +1 and -1 range

                    if (~isempty(t1) | ~isempty(t2)) & (~isempty(t3) | ~isempty(t4))
                        ta = [t1' t2'];
                        a = [a1' a2'];
                        te = [t3' t4'];
                        e = [e1' e2'];

                        tee = repmat(te, 1, length(ta));
                        ee = repmat(e, 1, length(ta));
                        taa = repmat(ta, 1, length(te));
                        aa = repmat(a, 1, length(te));
                        if any(abs(tee - taa) <= 5)
                            mask = abs(tee - taa) <= 5;
                            ta = taa(mask);
                            a = aa(mask);
                            te = tee(mask);
                            e = ee(mask);
                            ta = datetime('21-May-2024 00:00:00') + seconds(ta);
                            te = datetime('21-May-2024 00:00:00') + seconds(te);

                            subplot(2,1,1)
                            plot(ta, a, 'go', 'DisplayName', 'Intersections')

                            subplot(2,1,2)
                            plot(te, e, 'go', 'DisplayName', 'Intersections')

                            inter = inter + sum(mask);
                        end
                    end
                    holder = i;
                    %adjusts holder and the start of the new section
                end
            end

            %ending the section loop and finally doing the plot for the holder
            %to the end, which was missed by the loop
            subplot(2,1,1)
            hold on
            plot(timeBaseTemp(holder:end),azimuthTemp(holder:end), 'b', 'DisplayName', names{j})

            subplot(2,1,2)
            hold on
            plot(timeBaseTemp(holder:end),elevationTemp(holder:end), 'b', 'DisplayName', names{j})

            [~,idi] = min(abs(timeMast-timeTemp(holder)));
            if idi+1 <= lMast && timeMast(idi) - timeMast(idi+1) < 20
                p=0;
                while idi+1+p <= lMast && timeMast(idi+p+1)-timeMast(idi+p) < 20
                    p = p+1;
                end
                [t1,a1] = polyxpoly(timeTemp(holder:end),azimuthTemp(holder:end),timeMast(idi:idi+p),(azimuthMast(idi:idi+p))+1);
                [t2,a2] = polyxpoly(timeTemp(holder:end),azimuthTemp(holder:end),timeMast(idi:idi+p),(azimuthMast(idi:idi+p))-1);
                [t3,e1] = polyxpoly(timeTemp(holder:end),elevationTemp(holder:end),timeMast(idi:idi+p),(elevationMast(idi:idi+p))+1);
                [t4,e2] = polyxpoly(timeTemp(holder:end),elevationTemp(holder:end),timeMast(idi:idi+p),(elevationMast(idi:idi+p))-1);
            end

            if (~isempty(t1) | ~isempty(t2)) & (~isempty(t3) | ~isempty(t4))
                ta = [t1' t2'];
                a = [a1' a2'];
                te = [t3' t4'];
                e = [e1' e2'];

                tee = repmat(te, 1, length(ta));
                ee = repmat(e, 1, length(ta));
                taa = repmat(ta, 1, length(te));
                aa = repmat(a, 1, length(te));
                if any(abs(tee - taa) <= 5)
                    mask = abs(tee - taa) <= 5;
                    ta = taa(mask);
                    a = aa(mask);
                    te = tee(mask);
                    e = ee(mask);
                    ta = datetime('21-May-2024 00:00:00') + seconds(ta);
                    te = datetime('21-May-2024 00:00:00') + seconds(te);
                    subplot(2,1,1)
                    plot(ta, a, 'go', 'DisplayName', 'Intersections')

                    subplot(2,1,2)
                    plot(te, e, 'go', 'DisplayName', 'Intersections')
                    inter = inter + sum(mask);
                end
            end
        end

        if inter > 0
            answer = [names{masterNum} ' and ' names{j} ' intercept ' num2str(inter) ' time(s)'];
        else
            answer = [names{masterNum} ' and ' names{j} ' do not intercept'];
        end
            %adjusting output for each pair saying whether or not they
            %intercept
   
        holder = 1;
        for i = 2:lMast
            timeMastPlot = plotTime(:,masterNum);
            timeMastPlot(zeroMast) = [];
            if timeMast(i) - timeMast(i-1) >= 1800
                subplot(2,1,1)
                hold on
                plot(timeMastPlot(holder:i-1),azimuthMast(holder:i-1)+1, 'r', 'DisplayName', names{masterNum})
                plot(timeMastPlot(holder:i-1),azimuthMast(holder:i-1)-1, 'r', 'DisplayName', names{masterNum})

                subplot(2,1,2)
                hold on
                plot(timeMastPlot(holder:i-1),elevationMast(holder:i-1)+1, 'r', 'DisplayName', names{masterNum})
                plot(timeMastPlot(holder:i-1),elevationMast(holder:i-1)-1, 'r', 'DisplayName', names{masterNum})

                holder = i;
            end
        end
        subplot(2,1,1)
        hold on
        plot(timeMastPlot(holder:end),azimuthMast(holder:end)+1, 'r', 'DisplayName', names{masterNum})
        plot(timeMastPlot(holder:end),azimuthMast(holder:end)-1, 'r', 'DisplayName', names{masterNum})

        subplot(2,1,2)
        hold on
        plot(timeMastPlot(holder:end),elevationMast(holder:end)+1, 'r', 'DisplayName', names{masterNum})
        plot(timeMastPlot(holder:end),elevationMast(holder:end)-1, 'r', 'DisplayName', names{masterNum})
        %same thing as with the temporary satellite, finds each time
        %section and plots it

        subplot(2,1,1)
        legend(legendUnq(), 'Location', 'northeastoutside')
        title({sprintf('Pairing: %s & %s',names{masterNum}, names{j}), 'Time vs. Azimuth'})
        xlabel('Time')
        ylabel('Azimuth (degrees)')

        subplot(2,1,2)
        legend(legendUnq(), 'Location', 'northeastoutside')
        title({sprintf('Pairing: %s & %s',names{masterNum}, names{j}), 'Time vs. Elevation'})
        xlabel('Time')
        ylabel('Elevation (degrees)')
        %adjusting the viewing of the figure

        saveas(f, sprintf('%s_%s.fig',names{masterNum}, names{j}))
        %save figures to folder

        out = [out; {answer}];
        %starts loop again but with a new temporary satellite
    end

    toc
    %end timer
end