function voxelizer(vtk_input, vtk_output)
    % ensure types
    assert(isa(vtk_input, 'char'))
    assert(isa(vtk_output, 'char'))
    
    % read vtk and set volume size
    [v,f] = read_vtk(vtk_input);
    vox = max(v)-min(v);
    vox = ceil(vox / max(vox) * 256);
    
    % voxelize mesh using Aitkenhead's tool 
    fv = struct('vertices', v, 'faces', f+1);
    [volume,x,y,z] = VOXELISE(vox(1), vox(2), vox(3), fv, 'xyz');
    volume = padarray(volume, [20, 20, 20]);
    volume = imfill(volume, 26, 'holes');

    % convert to double type
    volume = double(volume);
    volume(volume == 1) = 255;

    % Guassian smoothing to sufficiently envelop the mesh
    volume = imgaussfilt3(volume,2);

    % Closing operation
    se = offsetstrel('ball', 15, 15);
    volume = imclose(volume, se);

    % Dilation operation
    se = offsetstrel('ball', 1, 1);
    volume = imdilate(volume, se);

    % conversion to binary volume
    volume = double(volume > 25) * 255;

    % Iso-surface generation
    [f1, v1] = isosurface(volume, 1);
    
    % Surface adjustment
    v2 = [v1(:,2) v1(:,1) v1(:,3)]; % yxz
    v2 = v2 + repmat(-min(v2), size(v1,1), 1);  % translation to the origin
    v2 = v2 .* repmat((max([max(x) max(y) max(z);max(v)])-min([min(x) min(y) min(z);min(v)]))./max(v2),size(v1,1),1);   % scaling
    v2 = v2 + repmat(min([min(x) min(y) min(z);min(v)]) + [0.5 0 -0.5], size(v1,1),1);  % origin adjustment
    v2 = v2 * 1.02; % ensure full converage
    
    % largest connected component
    A = adjacency(f1);
    bins = conncomp(graph(A));
    tab1 = find(bins == 1);
    tab2 = zeros(max(f1(:)),1);
    tab2(tab1) = 1: length(tab1);
    v3 = v2(tab1, :);
    f3 = f1;
    valid = sum(ismember(f1, tab1),2);
    f3(valid < 3, :) = [];
    f3 = tab2(f3);
    
    % write output
    write_vtk(vtk_output, v3, f3 - 1);
end

function A = adjacency(f)
    n = max(f(:));

    % remove duplicated edges
    rows = [f(:,1); f(:,1); f(:,2); f(:,2); f(:,3); f(:,3)];
    cols = [f(:,2); f(:,3); f(:,1); f(:,3); f(:,1); f(:,2)];
    rc = unique([rows,cols], 'rows','first');

    % fill adjacency matrix
    A = sparse(rc(:,1),rc(:,2),1,n,n);    
end