function out = text_contains_num(text,nums)

cnum = zeros(length(nums),1);

for in = 1:length(nums)
    cnum(in) = contains(text,sprintf('%d',nums(in)));
    
end

out = any(cnum);


end