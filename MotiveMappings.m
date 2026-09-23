function mappings = MotiveMappings(settings)
%MOTIVEMAPPINGS Derive bridge topics/IDs from the same selected vehicle registry.
    mappings=struct('name',{},'id',{},'topic',{},'childFrameId',{});
    for s=settings
        if strlength(s.motiveName)==0 && isnan(s.motiveId), continue; end
        mappings(end+1)=struct('name',s.motiveName,'id',s.motiveId, ...
            'topic',s.odometryTopic,'childFrameId',s.name+"/base_link"); %#ok<AGROW>
    end
    assert(~isempty(mappings),'MotiveRosBridge:NoMappings','No enabled Motive mappings in the vehicle registry.');
    ids=[mappings.id];
    ids=ids(~isnan(ids));
    assert(numel(unique(ids))==numel(ids),'MotiveRosBridge:DuplicateMapping', ...
        'Each Motive streaming ID must identify one vehicle.');
    names=string({mappings.name});
    names=names(isnan([mappings.id]));
    assert(numel(unique(names))==numel(names),'MotiveRosBridge:DuplicateMapping', ...
        'Each Motive name must identify one vehicle.');
end
