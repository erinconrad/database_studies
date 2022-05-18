function first = find_first_x(x)

nx = length(x);
first = nan;
for i = 1:nx
    if x(i) == 1
        first = i;
        break
    end
end

end