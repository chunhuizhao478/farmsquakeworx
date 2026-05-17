lc = 200;

Point(1) = {-1000, -1000, 0.0, lc};
Point(2) = {1000, -1000, 0.0, lc};
Point(3) = {1000, 1000, 0.0, lc};
Point(4) = {-1000, 1000, 0.0, lc};

Point(5) = {-500, 0.0, 0.0, lc};
Point(6) = {500, 0.0, 0.0, lc};

Line(1) = {1,2};
Line(2) = {2,3};
Line(3) = {3,4};
Line(4) = {4,1};

Line(5) = {5,6};

Line Loop(1) = {1,2,3,4};
Plane Surface(2) = {1};

Point{5,6} In Surface{2};
Line{5} In Surface{2};

Physical Curve("fault_1") = {5};

Physical Curve("bottom") = {1};
Physical Curve("right") = {2};
Physical Curve("top") = {3};
Physical Curve("left") = {4};

Physical Surface("100") = {2};

Mesh.Algorithm = 6;
