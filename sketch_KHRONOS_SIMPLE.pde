/********************************************************************************************************************************************************************************/
/*  KHRONOS PROJECTOR (Simplified Version Coded in PROCESSING <www.processing.org>, not using openGL acceleration hardware nor 3D textures)                                     */
/*  Copyright (C) 2005, ALVARO CASSINELLI <http://www.k2.t.u-tokyo.ac.jp/members/alvaro/Khronos>                                                                                */                                                                                                                  
/*  Note (1): use of this code, part of this code or exploitation of the proposed video/image manipulation mechanism is -in principle- allowed for non-commercial               */
/*  purposes as long as proper credit is given, including if possible a link or reference to the main project page: http://www.k2.t.u-tokyo.ac.jp/members/alvaro/Khronos.       */
/*  (contact me at alvaro(at)hotmail.com if you want to be completely sure). For commercial applications, be sure to contact me!                                                */
/*  Note (2): A more versatile java version of this demo may be online, which may not necessarily correspond to this code for technical reasons.                                */
/*  Note (3): Image resolution, functionalities and speed of execution is limited in this Java demo, compared with the C++ version used in the Khronos Projector installation.  */
/*  Note (4): This code is made available in the Processing spirit of "sharing and learning from one another" - but I cannot guarantee that you will find here a "nice" example */
/* of coding practice, nor an optimized code.                                                                                                                                   */  
/********************************************************************************************************************************************************************************/

/*************************************************************************************************************************/
/*   ------------------------------------   COMMANDS  --------------------------------------------------------------     */
/*   [ MOUSE LEFT CLICK ] : Places a "temporal Punch"                                                                    */
/*   [ ENTER ]            : Change the Evolution Mode {SIMPLE RELAXATION, SPATIO-TEMPORAL RIPPLES}                       */       
/*   ------------------------------------    PARAMETERS  ------------------------------------------------------------    */
/*   [ k / l ]    : Control the size of the "temporal punch"                                                             */
/*   [ h / j ]    : Control the steepness of the borders of the "temporal punch"                                         */
/*   ------------------------------------  VIEWING MODES -----------------------------------------------------------     */
/*   [ SPACE ]              : Change the Rendering Mode {FLAT, VOLUME}                                                   */
/*   [ MOUSE RIGHT CLICK ]  : Control rotations when in VOLUME rendering mode                                            */
/*   [ ARROWS UP / DOWN  ]  : Zoom Control.                                                                              */
/*************************************************************************************************************************/

// -----------------------------------------------------------------------------------------------------------------------------------
// Program Modes:
int RENDERING_FLAT=0, RENDERING_3D=1; // rem: since Processing does not have "#define" directives, we will need to use "if" instead of "switch"
int TOTAL_RENDERING_MODES=2;
int rendering_Mode=RENDERING_FLAT; // default (initial) rendering mode

int EVOLUTION_MULTIPLICATIVE_RELAXATION=0, EVOLUTION_WATERWAVES=1;
int TOTAL_EVOLUTION_MODES=2;
int evolution_Mode=EVOLUTION_WATERWAVES;

// Other variables and their default initialization:
color background_color=color(60);

// Rotation parameters (rem: the intuitive rotation method using the mouse is adapted form Ben Fry examples in the Processing web page <www.processing.org>)
float xmag=0.61;
float ymag =-0.02; 
float newXmag=0.61;
float newYmag=-0.02; 

// Zoom control:
float scalFactor=0.93;

int numFrames=108;// Number of images in the sequence FIXED here (for use with the "moni.jpg" set of 108 images - from 0 to 107)
String nameSequence="moni";
// Size of image, FIXED here (for use with the "moni.jpg" set of images)
int sizeX=240, sizeY=320;

// Size of the spatio-temporal cutting surface:
// REM: these parameters can be changed while the program is running, but in this case, they must be INITIALIZED to their maximum value, i.e, sizeX and sizeY!
int surX=sizeX, surY=sizeY; 

// Parameters for the pressure shape (in this simplified P5 version of Khronos, only Circular Gaussian and Disc Sigmoid modes)
float SigmPlateau=sizeX/3.5, SigmSlope=SigmPlateau/2, SigmRes=sizeX/40;

float pressure=0; // mouse pressure

float depthBox=(sizeX+sizeY)/2;// this is to have "proportionate" box, not too large or too short on the z direction
float frameStep=1.5/numFrames;

// Surface "multiplicative" relaxation factor:
float relaxFactor=0.92;

// parameters of the physical based model for the water surface:
float water_damp=0.02;
float temporal_water_level=.26; // The "water level" is set somewhere in the middle of the video buffer

// The sequence of images:
PImage[] sequence = new PImage[numFrames];

//Resulting blended image, really useful in case we don't use directly the image on display:
PImage blended_image; 

// Spatio-temporal cutting surface array:
float[][][] Surface=new float[2][surX][surY]; // we use an auxiliary surface for computing water-like evolution
int currentSurface=0; // used to swap surface in water model

// -----------------------------------------------------------------------------------------------------------------------------------
void setup() 
{ 
  size(240, 320, P3D); //size(384, 512, P3D);//OPENGL); // rem: 384=240*1.6, 512=320*1.6
  blended_image=loadImage(nameSequence+"0.jpg"); // blended image is initialized with the first image of the sequence, so the size will be ok
  for (int k=0; k<numFrames; k++) sequence[k] =loadImage(nameSequence+nf(k,0)+".jpg");  
  // Initialization of the surfaces (necessary in case of water model):
  resetSurface(currentSurface, temporal_water_level); resetSurface(1-currentSurface, temporal_water_level);
  colorMode(RGB, 256); // (because the loaded images are RGB and pixels have 256 levels for each color component) 
  // After memory allocation is done, we CAN reduce the size of the surface grid:
  surX=floor(sizeX/2); surY=floor(sizeY/2);
}

// -----------------------------------------------------------------------------------------------------------------------------

void draw() { 
   
  // 1) First, mouse control of the pressure:
  if (mousePressed&&(mouseButton == LEFT)) pressure=constrain(pressure+6.0/numFrames, 0,1); // pressure is normalized betweem 0 and 1
  else   pressure=constrain(pressure-2.0/numFrames, 0, 1);

  if ((!mousePressed)||(mouseButton != RIGHT))  {
    // 2) Surface "natural" evolution:
    surfaceEvolution();
    // 3) Surface "imprinting" using the mouse input:
    surfaceImprinting();
    // 4) Spatio-Temporal fusion:
    spatioTemporalFusion();
  }
  // 5) Last, DISPLAY the image:
  drawThings();
}
  
// -----------------------------------------------------------------------------------------------------------------------------------
void drawThings() {
 if (rendering_Mode==RENDERING_FLAT) {
  // updatePixels(); // in case we use the image buffer from the current displaying window (but then, image size must match the windows size).
  //image(blended_image, (width-sizeX)/2, (height-sizeY)/2);
  image(blended_image,0,0, width, height);  
  // filter(BLUR,1); // rem: the function filter acts over the WHOLE displaying window!
  } 
  else if (rendering_Mode==RENDERING_3D) { // this is rendering as a 2D texture in space
  //Since there is no image rewritten to the window, we need to clear the window "manually":
  background(background_color);
  pushMatrix(); 
  translate(width/2, height/2, -120); 
  // rotation angles are updated from mouse WHEN RIGHT BUTTON IS PRESSED:
  // REM: method adapted form Ben Fry
  if (mousePressed && (mouseButton == RIGHT)) {
  newXmag = (mouseX-width/2)/float(width) * TWO_PI; 
  newYmag = (mouseY-height/2)/float(height) * TWO_PI; 
  float diff = xmag-newXmag; 
  if (abs(diff) >  0.01) { xmag -= diff/6.0; } 
  diff = ymag-newYmag; 
  if (abs(diff) >  0.01) { ymag -= diff/6.0; } 
  }
 // println("xmag: " + str(xmag) + " / ymag: "+ str(ymag)+" / newXmag: " + str(newXmag) + " / newYmag: " +str(newYmag));
  // Rotation: 
  rotateX(-ymag); rotateY(xmag); 
  // Scaling:
  scale(scalFactor); 
  
   // 1) A box:  
  noFill();
  stroke(160);
  box(sizeX, sizeY, depthBox);
   
  // 2) The surface with the texture mapped onto it:
  fill(153); // anything will do: in fact, if I don't activate it, the texture will not appear! (fill is inactive in order to draw the box)
  noStroke();
  float x=-sizeX/2;
  float y=-sizeY/2;
  float dx=1.0*(sizeX-1)/(surX-1);
  float dy=1.0*(sizeY-1)/(surY-1);
   for(int i=0; i<(surY-1); i++) { 
     beginShape(TRIANGLE_STRIP);//QUAD_STRIP
      texture(blended_image); // create the texture from the spatio-temporal blended image
    for(int j=0; j<surX; j++) { 
    float z1=-depthBox*Surface[currentSurface][j][i];
    float z2=-depthBox*Surface[currentSurface][j][i+1];
    vertex(x, y, z1+depthBox/2, x+sizeX/2, y+sizeY/2); // in fact, by default the texture coordinates corresponds to the pixel grid of the original image
    vertex(x, y+dy, z2+depthBox/2, x+sizeX/2, y+dy+sizeY/2); 
    x+=dx; 
    }
     endShape();
       y+=dy;
       x=-sizeX/2;
   }
    popMatrix();
  }
}

// -----------------------------------------------------------------------------------------------------------------------------------
void  surfaceImprinting() { // Updates surface shape from mouse input, only when button LEFT pressed
 if (mousePressed && (mouseButton == LEFT)) { //otherwise, do nothing!
 float auxpressure=pressure;
 if (evolution_Mode==EVOLUTION_WATERWAVES) auxpressure=temporal_water_level+pressure*(1-temporal_water_level);
// REM: size of the "block" may be SMALLER than surX*surY...
  for(int i=0; i<surY; i++) { 
  int cy=floor(i*(height-1)/(surY-1));
    for(int j=0; j<surX; j++) { 
      int cx=floor(j*(width-1)/(surX-1));
      Surface[currentSurface][j][i]= max(Surface[currentSurface][j][i],auxpressure/(1+exp((dist(cx,cy,mouseX, mouseY)-SigmPlateau)/SigmSlope)));
    } 
  } 
}
}

  // -----------------------------------------------------------------------------------------------------------------------------------

void spatioTemporalFusion() {  
// REM:Spatio-temporal fusion algorithm (directly, no use of 3D textures as in the C++ version - therefore it is very slow!):
  for(int i=0; i<sizeY; i++) { 
  int ind1=floor(1.0*i*(surY-1)/(sizeY-1));
    for(int j=0; j<sizeX; j++) { 
      // first, compute the frame index k:
      float depth=(numFrames-1)*Surface[currentSurface][floor(1.0*j*(surX-1)/(sizeX-1))][ind1];
      int k=floor(depth);  // rem: in this simplified version, there is no blending between consecutive images...
      blended_image.pixels[i*sizeX+j] =sequence[k].pixels[i*sizeX+j]; //directly from the sequence of images
    } 
  } 
}

// -----------------------------------------------------------------------------------------------------------------------------------

void resetSurface(int whichSurface, float level) {
 for(int i=0; i<surY; i++) { 
    for(int j=0; j<surX; j++) { 
      Surface[whichSurface][j][i] =  constrain(level, 0,1);
    } 
  } 
}

// -----------------------------------------------------------------------------------------------------------------------------------

void surfaceEvolution() {

if (evolution_Mode==EVOLUTION_MULTIPLICATIVE_RELAXATION) {
     simpleMultiplicativeRelax();     
}
else if (evolution_Mode==EVOLUTION_WATERWAVES) {
    waterWaves();    
    }
}
    
// -----------------------------------------------------------------------------------------------------------------------------------

void simpleMultiplicativeRelax() {
  // Updates surface shape using mouse coordinates:
  for(int i=0; i<surY; i++) { 
    for(int j=0; j<surX; j++) { 
      Surface[currentSurface][j][i]*=relaxFactor;
    } 
  } 
}

// -----------------------------------------------------------------------------------------------------------------------------------
// Water-like Evolution:
void  waterWaves() { 
// Navier Stokes equations simplified. Also, fluid_constant=gpDt^2/Dr^2 assumed to be equal to .5
// REM: seems that P5 has no pointer structures, so this makes a little more complicated the exchange of matrices. 
int newSurface=1-currentSurface;
int x,y;
	// Evolution of the matrix of heights (discretized differential equation):
	// IMPORTANT (NICE) REMARK: during the loop, Surface[currentSurface][][] is UNCHANGED, and when treating (x,y) cell, we only need the previous value in THAT cell...
	for(x=1; x<surX-1; x++)
		for(y=1; y<surY-1; y ++) {
		  Surface[newSurface][x][y] = ((Surface[currentSurface][x-1][y]+Surface[currentSurface][x+1][y]+Surface[currentSurface][x][y-1]+Surface[currentSurface][x][y+1])/2) - Surface[newSurface][x][y];
                  Surface[newSurface][x][y]=constrain( Surface[newSurface][x][y] - (Surface[newSurface][x][y]-temporal_water_level)*water_damp, 0, 1); //relaxation towards the "water level"
		}

	// rem: treat borders a little differently, to make the map periodic:
	// first, right and left borders (no corners):
	for(y=1; y<surY-1; y ++)
	{
		// left border: x=0, and then x-1 corresponds to surX-1
		Surface[newSurface][0][y] = ((Surface[currentSurface][surX-1][y]+Surface[currentSurface][1][y]+Surface[currentSurface][0][y-1]+Surface[currentSurface][0][y+1]) /2) - Surface[newSurface][0][y];
		Surface[newSurface][0][y]= constrain(Surface[newSurface][0][y] - (Surface[newSurface][0][y] - temporal_water_level)*water_damp, 0, 1);
	
		// right border: x=surX-1, and then x+1 corresponds to x=0 
		Surface[newSurface][surX-1][y] = ((Surface[currentSurface][surX-2][y]+Surface[currentSurface][0][y]+Surface[currentSurface][surX-1][y-1]+Surface[currentSurface][surX-1][y+1]) /2) - Surface[newSurface][surX-1][y];
		Surface[newSurface][surX-1][y] = constrain(Surface[newSurface][surX-1][y]- (Surface[newSurface][surX-1][y]-temporal_water_level)*water_damp, 0, 1);
	}
	// then, upper and lower borders (no corners):
	for(x=1; x<surX-1; x ++)
	{
		// upper border: y=surY-1, and then y+1 corresponds to y=0
		Surface[newSurface][x][surY-1] = ((Surface[currentSurface][x-1][surY-1]+Surface[currentSurface][x+1][surY-1]+Surface[currentSurface][x][surY-2]+Surface[currentSurface][x][0]) /2) - Surface[newSurface][x][surY-1];
		Surface[newSurface][x][surY-1]= constrain(Surface[newSurface][x][surY-1] - (Surface[newSurface][x][surY-1] - temporal_water_level)*water_damp, 0, 1);
	
		// lower border: y=0, and then y-1 corresponds to y=surY-1:
		Surface[newSurface][x][0] = ((Surface[currentSurface][x-1][0]+Surface[currentSurface][x+1][0]+Surface[currentSurface][x][surY-1]+Surface[currentSurface][x][1]) /2) - Surface[newSurface][x][0];
		Surface[newSurface][x][0] = constrain(Surface[newSurface][x][0]- (Surface[newSurface][x][0]-temporal_water_level)*water_damp, 0, 1);
	}
	// finally, treat the corners:
	// (x=0,y=0):
        Surface[newSurface][0][0] = ((Surface[currentSurface][surX-1][0]+Surface[currentSurface][1][0]+Surface[currentSurface][0][surY-1]+Surface[currentSurface][0][1]) /2) - Surface[newSurface][0][0];
	Surface[newSurface][0][0] = constrain(Surface[newSurface][0][0]- (Surface[newSurface][0][0]-temporal_water_level)*water_damp, 0, 1);

	// (x=surX-1,y=0):
        Surface[newSurface][surX-1][0] = ((Surface[currentSurface][surX-2][0]+Surface[currentSurface][0][0]+Surface[currentSurface][surX-1][surY-1]+Surface[currentSurface][surX-1][1]) /2) - Surface[newSurface][surX-1][0];
        Surface[newSurface][surX-1][0] = constrain(Surface[newSurface][surX-1][0]- (Surface[newSurface][surX-1][0]-temporal_water_level)*water_damp, 0, 1);

	// (x=surX-1,y=surY-1):
        Surface[newSurface][surX-1][surY-1] = ((Surface[currentSurface][surX-2][surY-1]+Surface[currentSurface][0][surY-1]+Surface[currentSurface][surX-1][surY-2]+Surface[currentSurface][surX-1][0]) /2) - Surface[newSurface][surX-1][surY-1];
        Surface[newSurface][surX-1][surY-1] = constrain(Surface[newSurface][surX-1][surY-1]- (Surface[newSurface][surX-1][surY-1]-temporal_water_level)*water_damp, 0, 1);

	// (x=0,y=surY-1): 
        Surface[newSurface][0][surY-1] = ((Surface[currentSurface][surX-1][surY-1]+Surface[currentSurface][1][surY-1]+Surface[currentSurface][0][surY-2]+Surface[currentSurface][0][0]) /2) - Surface[newSurface][0][surY-1];
        Surface[newSurface][0][surY-1] = constrain(Surface[newSurface][0][surY-1]- (Surface[newSurface][0][surY-1]-temporal_water_level)*water_damp, 0, 1);

	// Last, swap buffer indexes as we advance in time:
	currentSurface=1-currentSurface;
}
// -----------------------------------------------------------------------------------------------------------------------------------

// Keyboard control: // rem: it is better to avoid changing values of important variables in this function (accessed by callback), because they may be some inconsistencies in other parts of the program. 
void keyPressed() {
 keyboardProcessing();
}
// -----------------------------------------------------------------------------------------------------------------------------------

void keyboardProcessing() {
if (key == ' ') { 
      rendering_Mode=1-rendering_Mode; // ** REM: this is a shortcut (because there are only two rendering modes now), but it's not "nice programming"
       background(background_color); // This is for clearing the screen (rem: normally, it is recommended NOT to write anything in this block!)
    } 
  // Control computation grid size (surface): 
  else if ((key == 'm')||(key == 'M')) {surX=constrain(surX+2, 2, sizeX); surY=constrain(surY+2, 2, sizeY); }
  else if ((key == 'n')||(key == 'N')) {surX=constrain(surX-2, 2, sizeX); surY=constrain(surY-2, 2, sizeY); }
 
   // Control brush parameters:
   else if ((key == 'l')||(key == 'L')) {SigmPlateau=constrain(SigmPlateau+SigmRes, 1, 5*sizeX); }
   else if ((key == 'K')||(key == 'k')) {SigmPlateau=constrain(SigmPlateau-SigmRes, 1, 5*sizeX); }
   else if ((key == 'h')||(key == 'H')) {SigmSlope=constrain(SigmSlope-SigmRes, 1, 5*sizeX);}
   else if ((key == 'J')||(key == 'j')) {SigmSlope=constrain(SigmSlope+SigmRes, 1, 5*sizeX); } 
  
    // Scaling: 
    else if ( keyCode == DOWN ) {scalFactor*=.96; } 
    else if ( keyCode == UP ) {scalFactor/=.96; } 
  
   // Change of evolution modes: 
   else if (keyCode == ENTER) { // then, change the mode of evolution:
   evolution_Mode=(evolution_Mode+1)%TOTAL_EVOLUTION_MODES; // 
   if (evolution_Mode==EVOLUTION_WATERWAVES) {resetSurface(0,temporal_water_level); resetSurface(1,temporal_water_level);}
  }
}
