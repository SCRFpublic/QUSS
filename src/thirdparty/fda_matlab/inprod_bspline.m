function prodmat = inprod_bspline(fdobj1, fdobj2, deriv1, deriv2)
%INPROD_BSPLINE  computes matrix of inner products of the derivatives
%  of order DERIV1 and DERIV2 of two functional data objects
%  FD1 and FD2, respectively.
%  These must both have Bspline bases, and these bases must have
%  a common break point sequence.   However, the orders can differ.
%  If only the first argument is present, the inner products of
%  FD1 with itself is taken.  If argument DERIV is not supplied,
%  it is taken to be 0.
%

%  Last modified 6 September 2004

if nargin < 4, deriv2 = 0;  end
if nargin < 3, deriv1 = 0;  end

if nargin < 2, fdobj2 = fdobj1;  end

if ~strcmp(class(fdobj1),'fd')
    error('FD1 is not a functional data object.');
end
if ~strcmp(class(fdobj2),'fd')
    error('FD2 is not a functional data object.');
end

basis1 = getbasis(fdobj1);
type1  = getbasistype(basis1);
if ~strcmp(type1,'bspline')
    error('FD1 does not have a B-spline basis.');
end
range1  = getbasisrange(basis1);
breaks1 = [range1(1),getbasispar(basis1),range1(2)];
nbasis1 = getnbasis(basis1);
norder1 = nbasis1 - length(breaks1) + 2;

basis2 = getbasis(fdobj2);
type2  = getbasistype(basis2);
if ~strcmp(type2,'bspline')
    error('FD2 does not have a B-spline basis.');
end
range2  = getbasisrange(basis2);
breaks2 = [range2(1),getbasispar(basis2),range2(2)];
nbasis2 = getnbasis(basis2);
norder2 = nbasis2 - length(breaks2) + 2;

if any((range1 - range2) ~= 0)
    error('The argument ranges for FD1 and FD2 are not identical.');
end

%  check that break values are equal and set up common array

if length(breaks1) ~= length(breaks2)
    error('The numbers of knots for FD1 and FD2 are not identical');
end

if any((breaks1 - breaks2) ~= 0)
    error('The knots for FD1 and FD2 are not identical.');
else
    breaks = breaks1;
end

if length(breaks) < 2
    error('The length of argument BREAKS is less than 2.');
end

breakdiff = diff(breaks);
if min(breakdiff) <= 0
    error('Argument BREAKS is not strictly increasing.');
end

%  set up the two coefficient matrices

coef1 = getcoef(fdobj1);
if length(size(coef1)) ~= 2
    error('FD1 is not univariate.');
end

coef2 = getcoef(fdobj2);
if length(size(coef2)) ~= 2
    error('FD2 is not univariate.');
end

n  = size(breaks,2);
L  = n - 1;            %  number of intervals defined by BREAKS
M1 = L + norder1 - 1;  %  number of basis functions for first  spline
M2 = L + norder2 - 1;  %  number of basis functions for second spline

if size(coef1) ~= M1 | size(coef2) ~= M2
    error(['Error: coef1 should be should have length #breaks+norder1-2',
           ' and coef2 #breaks+norder2-2.']);
end

breaks1 = breaks(1);
breaksn = breaks(n);

% The knot sequences are built so that there are no continuity conditions 
% at the first and last breaks.  There are k-1 continuity conditions at 
% the other breaks.

temp = breaks(2:(n-1));
t1   = [breaks1*ones(1,norder1),temp,breaksn*ones(1,norder1)]; 
t2   = [breaks1*ones(1,norder2),temp,breaksn*ones(1,norder2)]; 

% Construct  the piecewise polynomial representation of 
%    f^(DERIV1) and g^(DERIV2)

n1 = size(coef1,2);
polycoef1 = zeros(L,norder1-deriv1,n1); 
for i = 1:M1 
    %  compute polynomial representation of B(i,norder1,t1)(x)
    [Coeff,index] = ppBspline(t1(i:i+norder1));
    % convert the index of the breaks in t1 to the index in the
    % variable 'breaks'
    index = index + i - norder1;
    CoeffD = ppderiv(Coeff,deriv1); % differentiate B(i,norder1,t1)(x)
    % add the polynomial representation of B(i,norder1,t1)(x) to f
    if n1 == 1
        polycoef1(index,:,1) = coef1(i).*CoeffD +  polycoef1(index,:,1);
    else
        for in=1:length(index)
            polycoef1(index(in),:,:) = CoeffD(in,:)'*coef1(i,:) + ...
                            squeeze(polycoef1(index(in),:,:)); 
        end
    end
end

n2 = size(coef2,2);
polycoef2 = zeros(L,norder2-deriv2,n2); 
for i = 1:M2 
    %  compute polynomial representation of B(i,norder2,t2)(x)
    [Coeff,index] = ppBspline(t2(i:i+norder2));
    % convert the index of the breaks in t2 to the index in the 
                            % variable 'breaks'
    index = index + i - norder2; 
    CoeffD = ppderiv(Coeff, deriv2); % differentiate B(i,norder2,t2)(x)
    % add the polynomial representation of B(i,norder2,t2)(x) to g
    if n2 == 1
        polycoef2(index,:,1) = coef2(i).*CoeffD +  polycoef2(index,:,1);
    else
        for in=1:length(index)
            polycoef2(index(in),:,:) = CoeffD(in,:)'*coef2(i,:) + ...
                            squeeze(polycoef2(index(in),:,:)); 
        end
    end
end

% Compute the scalar product between f and g

prodmat = zeros(n1,n2);
for j = 1:L
    % multiply f(i1) and g(i2) piecewise and integrate
    if n1 == 1
        c1 = polycoef1(j,:)';
    else
        c1 = squeeze(polycoef1(j,:,:));
    end
    if n2 == 1
        c2 = polycoef2(j,:)';
    else
        c2 = squeeze(polycoef2(j,:,:));
    end
    polyprodmat = polyprod(c1,c2);
    % compute the coefficients of the anti-derivative
    D = size(polyprodmat,3);
    delta = breaks(j+1) - breaks(j);
    power = delta;
    prodmati = zeros(n1,n2);
    for i=1:D
        prodmati = prodmati + power.*polyprodmat(:,:,D-i+1)./i;
        power = power*delta;
    end
    % add the integral to s
    prodmat = prodmat + prodmati; 
end

%  --------------------------------------------------------------

function convmat = polyprod(Coeff1, Coeff2)
% POLYCONV computes products of polynomials defined by columns of 
%   coefficient matrices Coeff1 and Coeff2

%  Last modified 30 October 2002

[polyorder1, norder1] = size(Coeff1);
[polyorder2, norder2] = size(Coeff2);
ndegree1 = polyorder1 - 1;
ndegree2 = polyorder2 - 1;

%  if the degrees are not equal, pad out the smaller matrix with 0s

if ndegree1 ~= ndegree2
    if ndegree1 > ndegree2
        Coeff2 = [Coeff2;zeros(ndegree1-ndegree2,norder2)];
    else
        Coeff1 = [Coeff1;zeros(ndegree2-ndegree1,norder1)];
    end
end

%  find order of the product

D = max([ndegree1,ndegree2]);  % maximum degree
N = 2*D+1;                     % order of product

%  compute the coefficients for the products

convmat = zeros(norder1,norder2,N);
for i=0:D-1
    ind = (0:i) + 1;
    convmat(:,:,i+1) = Coeff1(ind,    :)'*Coeff2(i-ind+2,:);
    convmat(:,:,N-i) = Coeff1(D-ind+2,:)'*Coeff2(D-i+ind,:);
end
ind = (0:D)+1;
convmat(:,:,D+1) = Coeff1(ind,:)'*Coeff2(D-ind+2,:);

if ndegree1 ~= ndegree2
    convmat = convmat(:,:,1:(ndegree1+ndegree2+1));
end

%  ---------------------------------------------------------------------

function [CoeffD] = ppderiv(Coeff, Deriv)
%PPDERIV computes the DERIV-th derivatives of the polynomials 
% with coefficients COEFF such that the i-th polynomial is
% COEFF(i,1)*x^(k-1) + COEFF(i,2)*x^(k-2) + ... + COEFF(i,k)
% It returns a matrix COEFFD with the same number of rows as COEFF, 
% but with k-DERIV columns such that the DERIV-th derivative 
% of the i-th polynomial is expressed as
% COEFFD(i,1)*x^(k-1-DERIV) + COEFFD(i,k-DERIV-1)*x + COEFFD(i,k-DERIV),
% Note that if k-DERIV < 1, then COEFFD is the zero vector,
% and if DERIV < 1 we are not differentiating.

if nargin < 2
    Deriv = 0;
end

[m,k] = size(Coeff); % k is the order of the polynomials.

% If DERIV is not a positive integer, we are not differentiating.
if Deriv < 1
    CoeffD = Coeff; 
    return
end

% Compute the coefficient of the DERIV-th derivative of the function

if k-Deriv < 1
    CoeffD = zeros(m,1); % The derivative is zero everywhere
    return;
else
    % initialize COEFFD with the coefficients from COEFF we will need
    CoeffD = Coeff(:,1:k-Deriv); 
    for j=1:k-2
        bound1 = max(1,j-Deriv+1);
        bound2 = min(j,k-Deriv);
        CoeffD(:,bound1:bound2) = (k-j)*CoeffD(:,bound1:bound2);
    end
end