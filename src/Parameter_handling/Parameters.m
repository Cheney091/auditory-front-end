classdef Parameters < dynamicprops
    % Help on this class is a work in progress..
    
    properties (GetAccess = public, Hidden = true) % Private?
        map             % Map container for the parameter values
    end
    
    properties (GetAccess = public, Dependent = true, Hidden = true)
        description     % Map container for the description of individual parameters
    end
    
    
    methods
        
        function parObj = Parameters(keys,values)
            %Parameters   Constructor for the parameter object class
            
            if nargin<2; values = []; end
            if nargin<1; keys = []; end
            
            % Initialize a map container
            parObj.map = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            % Put keys and values in a cell if needed
            if ~iscell(keys) && ~isempty(keys)
                keys = {keys};
            end
            if ~iscell(values) && ~isempty(values)
                values = {values};
            end
            
            % Populate with provided keys and values
            if size(keys,2)~=size(values,2)
                warning(['Provided keys and values should have the same number of '...
                         'elements. Omitting them.'])
            else
                for ii = 1:size(keys,2)
                    parObj.map(keys{ii}) = values{ii};
                end
            end
            
            % Update dynamic properties
            parObj.updateProperties;
            
        end
          
        function processorParameters = getProcessorParameters(parameterObj,processorName)
            %getProcessorParameters     Extract the parameter values used
            %                           for a specific processor
            %
            %USAGE:
            % processorPar =
            %       parameterObj.getProcessorParameters(processorName)
            %
            %INPUT ARGUMENTS:
            %   parameterObj : Instance of parameter object
            %  processorName : Specific processor name
            %
            %OUTPUT ARGUMENTS:
            %   processorPar : New parameter object containing only the
            %                   parameters for that processor
            
            % Get the parameter keys from specific processor
            try
                keys = feval([processorName '.getParameterInfo']);
            
            catch
                warning(['There is no %s processor, or its getParameterInfo static '...
                         'method is not implemented!'],processorName)
                return
            end
            
            % Instantiate a new parameter object
            processorParameters = Parameters();
            
            % Copy the values from parameterObj with corresponding key
            for ii = 1:size(keys,2)
                if parameterObj.map.isKey(keys{ii})
                    processorParameters.map(keys{ii}) = parameterObj.map(keys{ii});
                else
%                     warning('No parameter named %s in this object.',keys{ii})
                    processorParameters.map(keys{ii}) = 'n-a';
                end
            end
            
        end
    
        function r = eq(parObj1,parObj2)
            % Overload equality between parameter objects
            
            % NB: Keys are naturally ordered in map containers, no need to do it here
            if isequal(parObj1.map.keys,parObj2.map.keys)
                r = isequal(parObj1.map.values,parObj2.map.values);
            else
                r = 0;
            end
            
        end
        
        function updateWithRequest(parObj,requestPar)
            %updateWithRequest  Adds parameters from a request to a parameter instance
            %
            %USAGE:
            %   parObj.updateWithRequest(requestPar)
            %
            %INPUT ARGUMENTS:
            %     parObj : Parameter object
            % requestPar : Parameter object to add to parObj
            
            if nargin<1; requestPar = []; end
            
            % Override the non-default values given in the request
            if ~isempty(requestPar)
                
                names = requestPar.map.keys;
                
                for ii = 1:size(names,2)
                    parObj.map(names{ii}) = requestPar.map(names{ii});
                end
            end
            
            % Update dynamic properties
            parObj.updateProperties;
            
        end
        
        function updateWithDefault(parObj,procName)
            %updateWithDefault  Adds default value to missing fields for a given processor
            %
            %USAGE:
            %   parObj.updateWithDefault(procName)
            %
            %INPUT ARGUMENTS:
            %     parObj : Parameter object
            %   procName : Name of the processor
            
            if nargin<2
                warning('Need to specify a processor name.')
                return
            end
            
            % Load the default parameters for that processor
            defaultPar = Parameters.getProcessorDefault(procName);
            names = defaultPar.map.keys;
            
            % Fill the missing or empty fields with default value
            for ii = 1:size(names,2)
                if ~parObj.map.isKey(names{ii}) || isempty(parObj.map(names{ii})) ...
                        || strcmp(parObj.map(names{ii}),'n-a')
                    parObj.map(names{ii}) = defaultPar.map(names{ii});
                end
            end
            
            % Update dynamic properties
            parObj.updateProperties;
            
        end
        
        function appendParameters(parObj,newParObj)
            %appendParameters   Appends new parameter properties to an existing object
            %
            %
            
            % Get a list of keyvalues to append
            keyList = newParObj.map.keys;
            
            if any(parObj.map.isKey(keyList))
                warning('Cannot append already existing parameters')
            else
                parObj.map = [parObj.map ; newParObj.map];
            end
            
            % Update dynamic properties
            parObj.updateProperties;
            
        end
        
        function replaceParameters(parObj,newParObj)
            %replaceParameters  Appends new parameter and replace value of existing ones
            
            % Get a list of keyvalues to append
            keyList = newParObj.map.keys;

            for ii = 1:size(keyList,2)
                % Will append a new parameter, or replace its value if already existing
                parObj.map(keyList{ii}) = newParObj.map(keyList{ii});
            end
            
            % Update dynamic properties
            parObj.updateProperties;
            
        end
         
        function parObjCopy = copy(parObj)
            %copy   Returns a new parameter object containing the same information
            %
            %USAGE:
            %  parObjCopy = parObj.copy;
            %
            %INPUT ARGUMENT:
            %      parObj : Parameter object
            %
            %OUTPUT ARGUMENT:
            %  parObjCopy : Copy of the parameter object
            
            parObjCopy = Parameters(parObj.map.keys, parObj.map.values);
            
        end
        
    end
    
    methods (Access = private)
        
        function updateProperties(parObj)
            
            n_param = parObj.map.Count;
            keys = parObj.map.keys;
            
            for ii = 1:n_param
                if ~isprop(parObj,keys{ii})
                    parObj.addDynProp(keys{ii});
                end
            end
            
            
        end
        
        function addDynProp(parObj,name)
            
            p = parObj.addprop(name);
            p.GetMethod = @get_method;
            p.Dependent = true;
            p.SetAccess = 'private';
            
            function value = get_method(parObj)
                value = parObj.map(name);
            end
            
        end
        
    end
    
    % "Getter" method
    methods
        function description = get.description(parObj)
            % This method will build a list of parameter description when the description
            % property is requested
            
            % Initialize the output
            description = containers.Map('KeyType', 'char', 'ValueType', 'char');
            
            % List of parameter names
            parList = parObj.map.keys;
            
            for ii = 1:size(parList,2)
                description(parList{ii}) = ...
                        Parameters.readParameterDescription(parList{ii});
            end
            
        end
    end
    
    methods (Static)
       
        function parObj = getProcessorDefault(processorName)
            %getProcessorDefault    Returns the default parameter for a given processor
            %
            %USAGE:
            %  values = Parameters.getProcessorDefault(procName)
            %
            %INPUT ARGUMENTS:
            %    procName : Name of the processor
            %
            %OUTPUT ARGUMENTS:
            %      parObj : Parameter object with default parameters for that processor
            
            % Load parameter names and default values
            try
                [names,values] = feval([processorName '.getParameterInfo']);
            catch
                if ~ismember(processorName,Processor.processorList)
                    warning(['There is no ''%s'' processor. Currently valid processor '... 
                             'names are the following: %s'], ...
                             processorName, ...
                             strjoin(Processor.processorList.',', '))
                    parObj = [];
                    return
                else
                    warning(['The .getParameterInfo static method of processor %s ' ...
                             'is not implemented!'],processorName)
                    parObj = [];
                    return
                end
            end
            
            % Put these in a parameter object
            parObj = Parameters(names,values);
            
        end
        
        function parObj = getPlottingParameters(signalName)
            %getPlottingParameters    Returns the default plotting parameters for a signal
            %
            %USAGE:
            %  values = Parameters.getPlottingParameters(signalName)
            %
            %INPUT ARGUMENTS:
            %  signalName : Name of the signal to plot
            %
            %OUTPUT ARGUMENTS:
            %      parObj : Parameter object with default parameters
            
            % Load parameter names and default values
            try
                [names, defaultValues, ~] = ...
                    feval([signalName '.getPlottingParameterInfo']);
            catch
                % Don't generate an error if this method is not found.
                names = {};
                defaultValues = {};
            end
            
            % Put these in a parameter object
            parObj = Parameters(names,defaultValues);
            
            % Add the common plotting parameters
            [commonName,commonValue,~] = Signal.getPlottingParameterInfo;
            commonParameters = Parameters(commonName, commonValue);
            parObj.appendParameters(commonParameters);
            
            
        end
        
        function text = readParameterDescription(parName)
            %readParameterDescription   Finds the description of a single parameter
            %
            %USAGE:
            %   text = Parameters.readParameterDescription(parName)
            %
            %INPUT ARGUMENTS:
            %   parName : Name of the parameter
            %
            %OUTPUT ARGUMENTS:
            %      text : Associated description
            
            % Find the name of the processor using this parameter
            procName = Processor.findProcessorFromParameter(parName,1);
            
            % Disable warnings
            warning('off','all')
            
            % Get the parameter infos
            if ~isempty(procName)
                [names,~,description] = feval([procName '.getParameterInfo']);
                text = description{strcmp(parName,names)};
            else
                % Maybe it is a plotting parameter, look in the signals
                sigName = Signal.findSignalFromParameter(parName,1);
                if ~isempty(sigName)
                    [names,~,description] = feval([sigName '.getPlottingParameterInfo']);
                    text = description{strcmp(parName,names)};
                else
                    warning('Could not find a parameter named %s.',parName)
                    text = 'n-a';
                end
            end
            
            warning('on','all')
            
        end
        
    end
    
end