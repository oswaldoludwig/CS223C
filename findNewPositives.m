function [newexamples] = findNewPositives(VOCopts, cls, newgt, newexamples, newimagenumbers,newdetector)

% load 'train' image set
ids=textread(sprintf(VOCopts.imgsetpath,'train'),'%s');

for i=1:length(newgt),
    image = ids{newimagenumbers(i)};
    if newgt(i)>=0,
        rec=PASreadrecord(sprintf(VOCopts.annopath,image));
        clsinds=strmatch(cls,{rec.objects(:).class},'exact');
        diff=[rec.objects(clsinds).difficult];
        bbox=cat(1,rec.objects(clsinds(~diff)).bbox)';
        
        fd = getFeatures(VOCopts,image);
        %newexamples(i,:)=findBest(VOCopts, fd,newdetector,bbox);
    end
end

%function [example] = findBest(VOCopts, fd,detector,)
