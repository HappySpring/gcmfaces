function [val]=gcmfaces_interp_2d(fld,lon,lat,method);
%[val]=GCMFACES_INTERP_2D(fld,lon,lat,method);
%   interpolates a gcmfaces field (fld) to a set of locations (lon, lat) 
%   using one of several methods: 'polygons' (default), 'natural', 'linear',
%   'nearest', or 'mix'.
%
%   If instead fld is is an array (of the same size as lon and lat)
%   then the field is interpolated to the gcmfaces grid (in mygrid).
%
%   The 'polygons' method is a particular implementation of bilinear 
%   interpolation on the sphere. The other methods applies on DelaunayTri
%   in longitude/latitude coordinates. In particular, the 'mix' option
%   is `natural' extended with 'nearest' when the input field 
%   has been land-masked with NaNs.
%
%Example:
%     lon=[-179.9:0.2:179.9]; lat=[-89.9:0.2:89.9];
%     [lat,lon] = meshgrid(lat,lon);
%     fld=mygrid.Depth.*mygrid.mskC(:,:,1);
%     [val]=gcmfaces_interp_2d(fld,lon,lat);
%     figureL; pcolor(lon,lat,val); shading flat;

% note: using gcmfaces_bindata to determine nearest neighbors on the sphere
% can be problematic. To illustrate the problem: uncomment the old
% method (using gcmfaces_bindata) in gcmfaces_loc_tile.m, set myenv.verbose
% to 2 and run the example as explained above. Points at the edge
% of tile 59 provide an example -- see display generated by
% gcmfaces_interp_coeffs.m

gcmfaces_global;

%backward compatibility checks:
if ~isfield(myenv,'useDelaunayTri');
    myenv.useDelaunayTri=~isempty(which('DelaunayTri'));
end;

if isempty(whos('method')); method='polygons'; end;

if ~ischar(method);
    error('fourth argument to gcmfaces_interp_2d is now ''method''');
end;

if ~myenv.useDelaunayTri&~strcmp(method,'polygons');;
    warning('DelaunayTri is missing -> reverting to old tsearch method');
    if ~isa(fld,'gcmfaces');
      error('old tsearch method only treats gcmfaces inputs (fld)');
    end;
end;

if ~isa(fld,'gcmfaces')&strcmp(method,'polygons');
    error('polygons method only treats gcmfaces inputs (fld)');
end;

%%use TriScatteredInterp
if strcmp(method,'linear')|strcmp(method,'nearest')|strcmp(method,'natural')|strcmp(method,'mix');

if isa(fld,'gcmfaces');
  XC=convert2array(mygrid.XC);
  YC=convert2array(mygrid.YC);
  VEC=convert2array(fld);
else;
  XC=lon;
  YC=lat;
  VEC=fld;
  lon=convert2gcmfaces(mygrid.XC);
  lat=convert2gcmfaces(mygrid.YC);
end;

val=NaN*lon;
for ii=1:3;
    if ii==1;
        myXC=XC; myXC(myXC<0)=myXC(myXC<0)+360;
        jj=find(lon>90);
    elseif ii==2;
        myXC=XC;
        jj=find(lon>=-90&lon<=90);
    else;
        myXC=XC; myXC(myXC>0)=myXC(myXC>0)-360;
        jj=find(lon<-90);
    end;
    kk=find(~isnan(myXC));
    TRI=DelaunayTri(myXC(kk),YC(kk));
    if strcmp(method,'mix');
        F = TriScatteredInterp(TRI, VEC(kk),'natural');
        tmp1=F(lon(jj),lat(jj));
        F = TriScatteredInterp(TRI, VEC(kk),'nearest');
        tmp2=F(lon(jj),lat(jj));
        tmp1(isnan(tmp1))=tmp2(isnan(tmp1));
        val(jj)=tmp1;
    else;
        F = TriScatteredInterp(TRI, VEC(kk),method);
        val(jj)=F(lon(jj),lat(jj));
    end;
end;

if ~isa(fld,'gcmfaces');
  val=convert2gcmfaces(val);
end;

end;

%%old linear interpolation method:
if strcmp(method,'tsearch');

    % Generate triangulation
    global mytri;
    gcmfaces_bindata;

    %switch longitude range to -180+180 or 0-360 according to grid
    if max(mygrid.XC)<0;
        lon(find(lon>180))=lon(find(lon>180))-360;
    end;
    if max(mygrid.XC)>180;
        lon(find(lon<0))=lon(find(lon<0))+360;
    end;

    % Find the nearest triangle (t)
    x=convert2array(mygrid.XC); x=x(mytri.kk);
    y=convert2array(mygrid.YC); y=y(mytri.kk);
    VEC=convert2array(fld); VEC=VEC(mytri.kk);
    t = tsearch(x,y,mytri.TRI,lon,lat);%the order of dims matters!!
    
    % Only keep the relevant triangles.
    out = find(isnan(t));
    if ~isempty(out), t(out) = ones(size(out)); end
    tri = mytri.TRI(t(:),:);
    
    % Compute Barycentric coordinates (w).  P. 78 in Watson.
    del = (x(tri(:,2))-x(tri(:,1))) .* (y(tri(:,3))-y(tri(:,1))) - ...
        (x(tri(:,3))-x(tri(:,1))) .* (y(tri(:,2))-y(tri(:,1)));
    w(:,3) = ((x(tri(:,1))-lon(:)).*(y(tri(:,2))-lat(:)) - ...
        (x(tri(:,2))-lon(:)).*(y(tri(:,1))-lat(:))) ./ del;
    w(:,2) = ((x(tri(:,3))-lon(:)).*(y(tri(:,1))-lat(:)) - ...
        (x(tri(:,1))-lon(:)).*(y(tri(:,3))-lat(:))) ./ del;
    w(:,1) = ((x(tri(:,2))-lon(:)).*(y(tri(:,3))-lat(:)) - ...
        (x(tri(:,3))-lon(:)).*(y(tri(:,2))-lat(:))) ./ del;
    
    val = sum(VEC(tri) .* w,2);    
    val(out)=NaN;
    val=reshape(val,size(lon));

end;%if strcmp(method,'tsearch');


%%use gcmfaces_interp_coeffs (under development):
if strcmp(method,'polygons');
    siz=size(lon);
    lon=lon(:);
    lat=lat(:);

    ni=30; nj=30;
    %ni=51; nj=51;
    map_tile=gcmfaces_loc_tile(ni,nj);

    loc_tile=gcmfaces_loc_tile(ni,nj,lon,lat);
    loc_tile=loc_tile.tileNo;
    [loc_interp]=gcmfaces_interp_coeffs(lon,lat,ni,nj);

    fld=exch_T_N(fld);
    [tmp1,tmp2,n3,n4]=size(fld{1});
    arr=NaN*zeros(length(lon),n3,n4);

    for ii_tile=1:max(map_tile);
        ii=find(loc_tile==ii_tile&nansum(loc_interp.w,2));
        if ~isempty(ii);
            %1) determine face of current tile
            tmp1=1*(map_tile==ii_tile);
            tmp11=sum(sum(tmp1,1),2); tmp12=[];
            for kk=1:tmp11.nFaces; tmp12=[tmp12,tmp11{kk}]; end;
            ii_face=find(tmp12);
            %... and its index range within face ...
            tmp1=tmp1{ii_face};
            tmp11=sum(tmp1,2);
            iiMin=min(find(tmp11)); iiMax=max(find(tmp11));
            tmp11=sum(tmp1,1);
            jjMin=min(find(tmp11)); jjMax=max(find(tmp11));

            %2) determine points and weights for next step
            interp_i=1+loc_interp.i(ii,:);
            interp_j=1+loc_interp.j(ii,:);
            interp_k=(interp_j-1)*(ni+2)+interp_i;%index after reshape
            interp_w=loc_interp.w(ii,:);%bininear weights

            %3) get the tile array
            til=fld{ii_face}(iiMin:iiMax+2,jjMin:jjMax+2,:,:);
            msk=1*(~isnan(til));
            til(isnan(til))=0;

            %4) interpolate each month to profile locations
            tmp0=repmat(interp_w,[1 1 n3 n4]);
            tmp1=reshape(til,[(ni+2)*(nj+2) n3 n4]);
            tmp2=reshape(msk,[(ni+2)*(nj+2) n3 n4]);
            tmp11=tmp1(interp_k(:),:); tmp11=reshape(tmp11,[size(interp_k) n3 n4]);
            tmp22=tmp2(interp_k(:),:); tmp22=reshape(tmp22,[size(interp_k) n3 n4]);
            tmp1=squeeze(sum(tmp0.*tmp11,2));
            tmp2=squeeze(sum(tmp0.*tmp22,2));
            arr(ii,:,:,:)=tmp1./tmp2;

        end;%if ~isempty(ii);
    end;%for ii_tile=1:117;

    if sum(siz~=1)<=1;
      val=reshape(arr,[prod(siz) n3 n4]);
    else;
      val=reshape(arr,[siz n3 n4]);
    end;
%   val=squeeze(reshape(arr,[siz n3 n4]));
%   if size(val,1)~=size(lon,1); val=val'; end;
end;

