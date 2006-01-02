/*
 ******************************************************************************
 * SimStarIV
 * Travis Cobbs, Chris Connley, Rusty Larner
 * CSC 480
 *
 * FILE:  TCVector.h
 ******************************************************************************
 */
#ifndef __TCVECTOR_H__
#define __TCVECTOR_H__

#include <TCFoundation/TCDefines.h>

#include <stdio.h>
//#include <windows.h>
//#include <GL/gl.h>

// All overload * operators with 2 vectors are cross product.
// dot product is not an overloaded operator, simply dot.

typedef TCFloat* GlPt;
typedef const TCFloat *ConstGlPt;

class TCVector
{
public:
	// Constructors
	TCVector(void);
	TCVector(TCFloat, TCFloat, TCFloat);
	TCVector(const TCFloat *);
	TCVector(const TCVector&);

	// Destructor
	~TCVector(void);

	// Member Functions
	void print(FILE* = stdout) const;
	void print(char* buffer, int precision = 3) const;
	TCFloat length(void) const;
	TCFloat lengthSquared(void) const;
	TCFloat dot(const TCVector&) const;
	TCVector& normalize(void) {return *this *= 1.0f/length();}
	TCFloat get(int i) const { return vector[i];}
	bool approxEquals(const TCVector &right, TCFloat epsilon) const;
	bool exactlyEquals(const TCVector &right) const;

	// Overloaded Operators
	TCVector operator*(const TCVector&) const;
	TCVector operator*(TCFloat) const;
	TCVector operator/(TCFloat) const;
	TCVector operator+(const TCVector&) const;
	TCVector operator-(const TCVector&) const;
	TCVector operator-(void) const;
	TCVector& operator*=(const TCVector&);
	TCVector& operator*=(TCFloat);
	TCVector& operator/=(TCFloat);
	TCVector& operator+=(const TCVector&);
	TCVector& operator-=(const TCVector&);
	TCVector& operator=(const TCVector&);
	int operator==(const TCVector&) const;
	int operator!=(const TCVector&) const;
	int operator<(const TCVector& right) const;
	int operator>(const TCVector& right) const;
	int operator<=(const TCVector& right) const;
	int operator>=(const TCVector& right) const;
	TCFloat& operator[](int i) {return vector[i];}
	operator GlPt(void) {return vector;}
	operator ConstGlPt(void) const {return vector;}
	TCVector mult(TCFloat* matrix) const;
	TCVector mult2(TCFloat* matrix) const;
	void transformPoint(const TCFloat *matrix, TCVector &newPoint);
	TCVector transformPoint(const TCFloat *matrix);
	void transformNormal(const TCFloat *matrix, TCVector& newNormal,
		bool shouldNormalize = true);
	TCVector transformNormal(const TCFloat *matrix,
		bool shouldNormalize = true);
	TCVector rearrange(int x, int y, int z) const;
	void upConvert(double *doubleVector);

	static TCFloat determinant(const TCFloat *matrix);
	static void multMatrix(const TCFloat *left, const TCFloat *right,
		TCFloat *result);
	static void multMatrixd(const double *left, const double *right,
		double *result);
	static TCFloat invertMatrix(const TCFloat *matrix, TCFloat *inverseMatrix);
	static void initIdentityMatrix(TCFloat*);
	static const TCFloat *getIdentityMatrix(void);
	static void doubleNormalize(double *v);
	static void doubleCross(const double *v1, const double *v2, double *v3);
	static void doubleAdd(const double *v1, const double *v2, double *v3);
	static void doubleMultiply(const double *v1, double *v2, double n);
	static double doubleLength(const double *v);
	static void fixPerpendicular(const double *v1, double *v2);
protected:
#ifdef _LEAK_DEBUG
	char className[4];
#endif
	TCFloat vector[3];
	static TCFloat identityMatrix[16];
};

// Overloaded Operator with non-TCVector as first argument
TCVector operator*(TCFloat, const TCVector&);

#endif // __TCVECTOR_H__
