// Where elements are as follows:
class ZSATransformMatrix
{
	// DO NOT EDIT
	double entries[4][4];
	static ZSATransformMatrix Create()
	{
		ZSATransformMatrix m = New("ZSATransformMatrix");
		return m;
	}
	
	static ZSATransformMatrix Yaw(double angle)
	{
		let matrix = Create();
		let c = cos(angle);
		let s = sin(angle);
		
		//	c	-s	0
		//	s	c	0
		//	0	0	1
		
		matrix.entries[0][0] = c;
		matrix.entries[0][1] = -s;
		matrix.entries[1][0] = s;
		matrix.entries[1][1] = c;
		matrix.entries[2][2] = 1;
		
		return matrix;
	}
	
	static ZSATransformMatrix Pitch(double angle)
	{
		let matrix = Create();
		let c = cos(angle);
		let s = sin(angle);
		
		//	c	0	s
		//	0	1	0
		//	-s	0	c
		
		matrix.entries[0][0] = c;
		matrix.entries[0][2] = s;
		matrix.entries[1][1] = 1;
		matrix.entries[0][2] = -s;
		matrix.entries[2][2] = c;
		
		return matrix;
	}
	
	static ZSATransformMatrix Roll(double angle)
	{
		let matrix = Create();
		let c = cos(angle);
		let s = sin(angle);
		
		//	1	0	0
		//	0	c	-s
		//	0	s	c
		
		matrix.entries[0][0] = 1;
		matrix.entries[1][1] = c;
		matrix.entries[1][2] = -s;
		matrix.entries[2][1] = s;
		matrix.entries[2][2] = c;
		
		return matrix;
	}
	
	static double Cot(double a)
	{
		return cos(a) / sin(a);
	}
	
	static ZSATransformMatrix Rotate(double roll = 0, double yaw = 0, double pitch = 0)
	{
		console.printf("rotating: roll %.2f yaw %.2f pitch %.2f", roll, yaw, pitch);
		ZSATransformMatrix m;
		
		let rM = ZSATransformMatrix.Roll(roll);
		// console.printf("rm\n%s", rm.ToStr());
		let pM = ZSATransformMatrix.Pitch(pitch);
		// console.printf("pm\n%s", pM.ToStr());
		let yM = ZSATransformMatrix.Yaw(yaw);
		// console.printf("ym\n%s", yM.ToStr());
		
		m = rM.MultiplyMatrices(pM, (3, 3));
		// console.printf("m after P\n%s", m.ToStr());
		m = m.MultiplyMatrices(yM, (3, 3));
		// console.printf("m after Y\n%s", m.ToStr());
		
		return m;
	}
	
	ZSATransformMatrix MultiplyMatrices(ZSATransformMatrix other, Vector2 size = (4, 4))
	{
		let m = ZSATransformMatrix.Create();
		
		for (int i = 0; i < size.x; i++)
		{
			for (int j = 0; j < size.y; j++)
			{
				m.entries[i][j] = 0;
				for (int k = 0; k < size.x; k++)
				{
					double a = self.entries[i][k];
					double b = other.entries[k][j];
					m.entries[i][j] += a * b;
					// console.printf("i %d j %d k %d   a %.2f b %.2f temp %.2f", i, j, k, a, b, m.entries[i][j]);
				}
			}
		}
		
		return m;
	}
	
	Vector3 ToEuler()
	{
		// x = roll = delta
		// y = yaw = alpha
		// z = pitch = beta
		double x, y, z;
		
		x = atan2(self.entries[2][1], self.entries[2][2]);
		y = atan2(self.entries[1][0], self.entries[0][0]);
		z = atan2(self.entries[2][0], sqrt((self.entries[2][1]**2) + (self.entries[2][2]**2)));
		
		console.printf("x y z %.2f %.2f %.2f", x, y, z);
		
		return (x, y, z);
	}
	
	Vector3 MultiplyVec3(Vector3 vec, Vector2 size = (3, 3))
	{
		double vecArr[3] = { vec.x, vec.y, vec.z };
		double result[3];
		
		for (int i = 0; i < size.x; i++)
		{
			for (int j = 0; j < size.y; j++)
			{
				result[j] += self.entries[j][i] * vecArr[i];
			}
		}
		
		console.printf("vec3: %.2f %.2f %.2f", result[0], result[1], result[2]);
		
		return (result[0], result[1], result[2]);
	}
	
	string ToStr()
	{
		String s = "";
		for (int i = 0; i < 4; i++)
		{
			for (int j = 0; j < 4; j++)
			{
				s = string.format("%s%.4f ", s, entries[i][j]);
			}
			s = string.format("%s\n", s);
		}
		return s;
	}
	
	static void TestMult()
	{
		let m1 = Create();
		m1.entries[0][0] = 1;
		m1.entries[0][1] = 2;
		m1.entries[0][2] = 0;
		m1.entries[0][3] = 2;
		
		m1.entries[1][0] = 3;
		m1.entries[1][1] = 1.0;
		m1.entries[1][2] = 2.0;
		m1.entries[1][3] = 1;
		
		m1.entries[2][0] = 4;
		m1.entries[2][1] = 1;
		m1.entries[2][2] = 3;
		m1.entries[2][3] = 1;
		
		m1.entries[3][0] = 1;
		m1.entries[3][1] = 5;
		m1.entries[3][2] = 2;
		m1.entries[3][3] = 0;
		
		let m2 = Create();
		m2.entries[0][0] = 1;
		m2.entries[0][1] = 2;
		m2.entries[0][2] = 0;
		m2.entries[0][3] = 2;
		
		m2.entries[1][0] = 3;
		m2.entries[1][1] = 1.0;
		m2.entries[1][2] = 2.0;
		m2.entries[1][3] = 1;
		
		m2.entries[2][0] = 4;
		m2.entries[2][1] = 1;
		m2.entries[2][2] = 3;
		m2.entries[2][3] = 1;
		
		m2.entries[3][0] = 1;
		m2.entries[3][1] = 5;
		m2.entries[3][2] = 2;
		m2.entries[3][3] = 0;
		
		let result = m1.MultiplyMatrices(m2);
		console.printf("m1:\n%s", m1.tostr());
		console.printf("m2:\n%s", m2.tostr());
		console.printf("rs:\n%s", result.tostr());
	}
}	