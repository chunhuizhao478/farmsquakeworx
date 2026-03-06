lc = 100;

Point(1) = {-26000, -20000, 0.0, lc};
Point(2) = {24000, -20000, 0.0, lc};
Point(3) = {24000, 20000, 0.0, lc};
Point(4) = {-26000, 20000, 0.0, lc};

Point(5) = {-16000, 0.0, 0.0, lc};
Point(6) = {12000, 0.0, 0.0, lc};
Point(7) = {200, -200, 0.0, lc};
Point(8) = {10392.3, -6000, 0.0, lc};
Point(9) = {200, 200, 0.0, lc};
Point(10) = {10392.3, 6000, 0.0, lc};
Point(11) = {0, 200, 0.0, lc};
Point(12) = {0, 1000, 0.0, lc};

Line(1) = {1,2};
Line(2) = {2,3};
Line(3) = {3,4};
Line(4) = {4,1};

Line(5) = {5,6};
Line(6) = {7,8};
Line(7) = {9,10};
Line(8) = {11,12};

Line Loop(1) = {1,2,3,4};
Plane Surface(2) = {1};

Point{5,6,7,8,9,10,11,12} In Surface{2};
Line{5,6,7,8} In Surface{2};

Physical Curve("fault_1") = {5};
Physical Curve("fault_2") = {6};
Physical Curve("fault_3") = {7};
Physical Curve("fault_4") = {8};

Physical Curve("bottom") = {1};
Physical Curve("right") = {2};
Physical Curve("top") = {3};
Physical Curve("left") = {4};

Physical Surface("100") = {2};

Mesh.Algorithm = 6;
