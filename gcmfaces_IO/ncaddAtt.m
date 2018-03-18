function ncaddAtt(ncid,varname,attrname,attrvalue);
% add an attribute to a variable in an existing netcdf file.

gcmfaces_global; if myenv.usingOctave; import_netcdf; end;

if isempty(varname),
    if myenv.useNativeMatlabNetcdf;
        netcdf.reDef(ncid);
        netcdf.putAtt(ncid,-1,attrname,attrvalue);
        netcdf.endDef(ncid);
    else;%try to use old mex stuff
        if ischar(attrvalue)
            attrvalue(find(double(attrvalue)==10))=[];
            eval(['ncid.' attrname '=''' attrvalue ''';']);
        else
            eval(['ncid.' attrname '=' num2str(attrvalue) ';']);
        end
    end;
else
    if myenv.useNativeMatlabNetcdf;
        varid=netcdf.inqVarID(ncid,varname);
        netcdf.reDef(ncid);
        netcdf.putAtt(ncid,varid,attrname,attrvalue);
        netcdf.endDef(ncid);
    else;%try to use old mex stuff
        if strcmp(attrname,'_FillValue'),
            attrname='FillValue_';
        end
        if ischar(attrvalue)
            attrvalue(find(double(attrvalue)==10))=[];
            eval(['ncid{''' varname '''}.' attrname '=''' attrvalue ''';']);
        else
            eval(['ncid{''' varname '''}.' attrname '=' num2str(attrvalue) ';']);
        end
    end;
end
    


