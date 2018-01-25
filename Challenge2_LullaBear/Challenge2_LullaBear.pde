import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.signals.*;
import ddf.minim.spi.*;
import ddf.minim.ugens.*;

//*********************************************
// Time-Series Signal Processing and Classification
// e9_LinearSVM_Gesture_Arduino_ThreeSensors
// Rong-Hao Liang: r.liang@tue.nl
//*********************************************
// The papaya library is included in the /code folder.
// Papaya: A Statistics Library for Processing.Org
// http://adilapapaya.com/papayastatistics/
// Before use, please make sure your Arduino has e sensor connected
// to the analog input, and SerialString_ThreeSensors.ino was uploaded. 
//[0-9] Change Label to 0-9
//[ENTER] Train the SVM
//[TAB] Increase Label Number
//[/] Clear the Data
// [SPACE] Pause Data Stream
// [A] Increase the Activation Threshold by 10
// [Z] Decrease the Activation Threshold by 10

import papaya.*; //statistic library for processing
import processing.serial.*;
import processing.sound.*;
import ddf.minim.*;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.stream.*;
Serial port;

//Sound Libraries and objects;
Minim minim;
AudioInput in;
AudioRecorder recorder;
AudioPlayer player, recPlayer;

int startRecordTime;


long timer = millis();
int waitTimer = 1000; // milliseconds
int prevPredicted = -1;

// Declare a scaling factor
int scale=5;

// Define how many FFT bands we want
int bands = 128;

// declare a drawing variable for calculating rect width
float r_width;

// Create a smoothing vector
float[] sum = new float[bands];

// Create a smoothing factor
float smooth_factor = 0.2;


int sensorNum = 4; //number of sensors in use
int dataNum = 500; //number of data to show
int[] rawData = new int[sensorNum]; //raw data from serial port
float[] postProcessedDataArray = new float[sensorNum]; //data after postProcessing
float[][] sensorHist = new float[sensorNum][dataNum]; //history data to show
boolean b_pause = false; //flag to pause data collection

float[][] diffArray = new float[sensorNum][dataNum]; //diff calculation: substract

float[] modeArray = new float[dataNum]; //To show activated or not
int activationThld = 40; //The diff threshold of activiation

int windowSize = 100; //The size of data window
float[][] windowArray = new float[sensorNum][windowSize]; //data window collection
boolean b_sampling = false; //flag to keep data collection non-preemptive
int sampleCnt = 0; //counter of samples

//Statistical Features
float[] windowM = new float[sensorNum]; //mean
float[] windowSD = new float[sensorNum]; //standard deviation
float[] windowMax = new float[sensorNum];
float[] windowMin = new float[sensorNum];
float[] windowF = new float[sensorNum]; //frequency

float[] windowRange = new float[sensorNum];  // sensorNum -1 cos not the microphone
boolean b_featureReady = false;


//SVM parameters
double C = 64; //Cost: The regularization parameter of SVM
int d = 3;     //Number of features to feed into the SVM
int lastPredY = -1;

String twinkleMom;
String twinkleDad;
String rockMom;
String rockDad;
String sunMom;
String sunDad;
String[] lullabies = new String[6];

int currentAction = 0;
int secondsUntilDemotion = 10;

int[] weight;
int totalWeight;
int tag;
boolean hasPicked = false;
boolean demoted = true;


// INTERFACE 
PImage backgroundImage, 
       babyRest, 
       babyRestless, 
       babyDistressed,
       iconPlay,
       iconStop;
       
float x = 350, y = 250, w = 60, h = 60;
boolean buttonPressed, alreadyRecorded;

ArrayList<Float> visual = new ArrayList<Float>();
ArrayList<Integer> recIndex = new ArrayList<Integer>();
ArrayList<String> recordings = new ArrayList<String>();
ArrayList<Boolean> green = new ArrayList<Boolean>();

int startHour, startMinute;



void setup() {
  size(1280, 720);
  background(255);
  fill(255);
  textFont(createFont("Helvetica", 25));
  frameRate(250);

  /************* INTERFACE********************/
  // load all images from the 'data' folder 
  backgroundImage = loadImage("data/GraphicsBG.png");
  
  babyRest = loadImage("data/BabyRest.png");
  babyRestless = loadImage("data/BabyRestless.png");
  babyDistressed = loadImage("data/BabyDistressed.png");
  
  image(backgroundImage, 0, 0, 1280, 720); // set the background image of the interface
  image(babyRest, 414, 62, 447, 447); // default state: baby is sleeping
  
  buttonPressed = false;
  alreadyRecorded = false;
  /**********************************/

  //Initiate the serial port
  for (int i = 0; i < Serial.list().length; i++) println("[", i, "]:", Serial.list()[i]);
  String portName = Serial.list()[1];//check the printed list
  port = new Serial(this, portName, 115200);
  port.bufferUntil('\n'); // arduino ends each data packet with a carriage return 
  port.clear();           // flush the Serial buffer

  for (int i = 0; i < modeArray.length; i++) { //Initialize all modes as null
    modeArray[i] = -1;
  }

  minim = new Minim(this);
  in = minim.getLineIn();
  player = minim.loadFile(sketchPath() + "/data/Rosa_rockabye_baby.mp3", 2048);
  recorder = minim.createRecorder(in, "babyvoice" + recordings.size() + ".wav");

  ///////////////////////////make so that it randomly selects from array///////////////////////////
  //declare all the lullabies, load them in and make & fill the array
  twinkleMom = "/data/twinkleMom.mp3";
  twinkleDad = "/data/twinkleDad.mp3";
  rockMom = "/data/rockMom.mp3";
  rockDad = "/data/rockDad.mp3";
  sunMom = "/data/sunMom.mp3";
  sunDad = "/data/sunDad.mp3";
  lullabies[0] = twinkleMom;
  lullabies[1] = twinkleDad;
  lullabies[2] = rockMom;
  lullabies[3] = rockDad;
  lullabies[4] = sunMom;
  lullabies[5] = sunDad;
  //weight declaration
  // 6 different states: 3*6+1 cant be lower than

  weight = new int[lullabies.length];
  totalWeight = (lullabies.length * 3 + 1) * lullabies.length;
  int perWeight = totalWeight/lullabies.length;
  
  println("Create weights array: totalWeight = " + totalWeight + ", perWeight: " + perWeight);

  for (int i = 0; i < weight.length; i++) {
    weight[i] = perWeight;
  }
  
  for (int i = 0; i < lullabies.length; i++) {
     green.add(false); 
  }
  
  // Adding first variable
  visual.add(0.0);


  startHour = hour();
  startMinute = minute();
  ///////////////////////////////////////////////////////////////////////////////////////////////////

  //file = new SoundFile(this, sketchPath()+"/data/Rosa_twinkle_twinkle.mp3");
  //file.play();

  // model = loadSVM_Model(sketchPath() + "/data/test.model"); //load an SVM here
   //svmTrained = true; //set true because it is loaded.
   //firstTrained = false; //set false because it is not the first training.
}




void draw() {
  
  /************* INTERFACE********************/
  
  image(backgroundImage, 0, 0, 1280, 720); // set the background image of the interface
  // display 'baby is sleeping' label as a default
  image(babyRest, 414, 62, 447, 447);
  
  text("January 18, 2018", 45, 65);
  
  pushStyle();
  noStroke();
  fill(12);
  rect(1175, 45, 75, 35);
  fill(255);
  text(hour() + ":" + minute() + ":" + second() , 1170, 45 + 25); // seconds instead of minutes for demo purposes
  
  
  textSize(13);
  fill(120, 120, 120);
  text("Night started: ", 15, 9 * height/10 + 20);
  text(startHour + ":" + startMinute, 15, 9 * height/10 + 40);   //   vertex(0, 9 * height/10);
  text("Slept until:", width-74, 9 * height/10 + 20);
  text(hour() + ":" + minute(), width-40, 9 * height/10 + 40); 
  
  popStyle();
  
  iconPlay = loadImage("data/button_play.png");
  iconStop = loadImage("data/button_stop.jpg");
  
  /******************************************************/

  if (!svmTrained && firstTrained) {
    //train a linear support vector classifier (SVC) 
    trainLinearSVC(d, C);
  }

  if (svmTrained) {

    pushStyle();

    switch(lastPredY) {
    case 1:

      if (prevPredicted != 1) {
        timer = millis();
      }

      if (prevPredicted == 2) { //&& hasPicked
        hasPicked = false;
        println("WeightChange label 1: true, i: " + currentAction);
        weightChange(true, currentAction);
      }

      if (millis() - timer > waitTimer) {    
        image(babyRest, 414, 62, 447, 447);
        //println("LABEL 1");
      }

      prevPredicted = 1;
      break;

    case 2:
    
      if (prevPredicted != 2) {
        timer = millis();
        hasPicked = false;
        demoted = false;
      }  


      if (millis() - timer > waitTimer) {
        image(babyRestless, 414, 62, 447, 447);
        //println("LABEL 2");

        if (millis() - timer > secondsUntilDemotion*waitTimer && !demoted) {  // && !demoted
          println("WeightChange label 2 TIME: false, i: " + currentAction);
          demoted = true;
          weightChange(false, currentAction);
        }

        ///////////////////////////////////action picking upon restless///////////////////////////////////

        //randomly chose a number between 0 and the total weight number
        if (!hasPicked && !player.isPlaying()) {

          hasPicked = true;
          int pick = int(random(totalWeight));
          println("pick "+pick);
          // Choosing which action to take based on weights
          for (int i = 0; i < lullabies.length; i++) {

            // Create subarray 1
            int sum1;
            
            if (i == 0) {
              sum1 = 0;
            } else {
              int[] sub1 = subset(weight, 0, i);
              sum1 = sumArray(sub1);
            }

            // create subarray 2
            int[] sub2 = subset(weight, 0, i+1);
            int sum2 = sumArray(sub2);

            if (pick >= sum1 && pick < sum2) {
              player = minim.loadFile(sketchPath()+lullabies[i], 2048);
              player.play();
              println("Currentaction: " + i);
              currentAction = i;
            }
          }
        }
      }


      prevPredicted = 2;
      break;

    case 3:
  
        if (prevPredicted != 3) {
          timer = millis();
          alreadyRecorded = false;
        }
  
        // Alert parents after 3 min (10 sec)
        if (millis() - timer > waitTimer*secondsUntilDemotion) {
          text("Alerting parents", 40, 90);
        }
  
        if (prevPredicted == 2) {  //&& hasPicked
          println("WeightChange label 3 : false, i: " + currentAction);
          weightChange(false, currentAction);
        }
  
        // Baby is awake
        if (millis() - timer > waitTimer*2) {
            image(babyDistressed, 414, 62, 447, 447);
            //println("LABEL 3");
            
            if (!alreadyRecorded) {
              
              alreadyRecorded = true;
              int timer = second() - startRecordTime; // create timer for the recorder
              println(timer);
              
              recIndex.add(visual.size());
              recorder = minim.createRecorder(in, "babyvoice" + (recIndex.size() - 1) + ".wav");
              recordings.add("babyvoice" + (recIndex.size() - 1) + ".wav");
              
              recorder.beginRecord(); // start recording
          
              // record sound for 10 seconds
              
              if (millis() - timer > 10000) {//&& recorder.isRecording()) {
                recorder.save(); // save recording
                println("Done saving.");
                recorder.endRecord(); // stop recording
                
              }    
            }
        }
  
        prevPredicted = 3;
        break;
      }
     
    popStyle();
  }
 
   // Draw graph for visualization of the nightf
   float[] data = new float[visual.size()];
   for (int i = 0; i < visual.size(); i++) {
       data[i] = (float) visual.get(i);
   }
   
   lineGraph(data);
   
   
   for (int i = 0; i < recIndex.size(); i++) {
      drawPlayButtons(i, recIndex.get(i), visual.size(), green.get(i)); 
   }
 
}

void serialEvent(Serial port) {   
  String inData = port.readStringUntil('\n');  // read the serial string until seeing a carriage return
  int dataIndex = -1;
  if (!b_pause) {
    //assign data index based on the header
    if (inData.charAt(0) == 'A') {  
      dataIndex = 0;
    }
    if (inData.charAt(0) == 'B') {  
      dataIndex = 1;
    }
    if (inData.charAt(0) == 'C') {  
      dataIndex = 2;
    }
    if (inData.charAt(0) == 'D') {  
      dataIndex = 3;
    }

    //data processing
    if (dataIndex >= 0) {
      rawData[dataIndex] = int(trim(inData.substring(1))); //store the value      
      postProcessedDataArray[dataIndex] = map(constrain(rawData[dataIndex], 0, 1023), 0, 1023, 0, height); //scale the data (for visualization)
      appendArray(sensorHist[dataIndex], rawData[dataIndex]); //store the data to history (for visualization)

      if (dataIndex <= 3) {
        float diff = abs(sensorHist[dataIndex][0] - sensorHist[dataIndex][1]); //absolute diff is used
        appendArray(diffArray[dataIndex], diff); //store the abs diff to history (for visualization)

        if (mousePressed || svmTrained) { //activate when the absolute diff is beyond the activationThld
          if (b_sampling == false) { //if not sampling
            b_sampling = true; //do sampling
            sampleCnt = 0; //reset the counter
            for (int i = 0; i < sensorNum; i++) {
              for (int j = 0; j < windowSize; j++) {
                windowArray[i][j] = 0; //reset the window
              }
            }
          }
        }
      }

      //***********************************************************************************************************************************************************************************/
      // WHAT WE WORKED ON SATURDAY 13/01
      // |
      // V

      if (b_sampling == true) {

        // Calcualtes the standard deviation, range and frequency per axis on accelerometer 

        appendArray(windowArray[dataIndex], rawData[dataIndex]); //store the windowed data to history (for visualization)
        sampleCnt++;

        if (sampleCnt == (windowSize * sensorNum)) {

          for (int i = 0; i < sensorNum; i++) {  // iterates each sensor

            windowM[i] = Descriptive.mean(windowArray[i]); // mean
            windowSD[i] = Descriptive.std(windowArray[i], true); //standard deviation
            windowMax[i] = Descriptive.max(windowArray[i]); // max
            windowMin[i] = Descriptive.min(windowArray[i]); // min

            // Calculate range for each axis
            windowRange[i] = windowMax[i] - windowMin[i];

            if (windowRange[i] >= 2) {

              //find frequency
              boolean passed = false;
              int freq = 0;

              for (int k = 0; k < windowArray[i].length; k++) {  // iterates each datapoint

                float threshold = windowM[i];

                if ((windowArray[i][k] > threshold) && !passed) {
                  freq++;
                  passed = true;
                }

                if ((windowArray[i][k] < threshold) && passed) {
                  passed = false;
                }
              }

              windowF[i] = freq;
              //System.out.println("freq: " + freq);
            } else {
              windowF[i] = 0;
            }
          }

          b_sampling = false; //stop sampling if the counter is equal to the window size
          b_featureReady = true;
        }
      }


      //when b_featureReader is true, use the data for classification
      if (dataIndex == 3) { // if the header is 'D', we collect the data as a set 
        if (b_featureReady == true) {

          // Create the feature array X
          double[] X = new double[5]; //Form a feature vector X;


          // Average the data across all three axis.
          float avgStdDev = ((windowSD[0] + windowSD[1] + windowSD[2]) / 3);
          float avgRange = ((windowRange[0] + windowRange[1] + windowRange[2]) / 3);
          float avgFreq = ((windowF[0] + windowF[1] + windowF[2]) / 3); 


          // merge to feature X  
          X[0] = avgStdDev;
          X[1] = avgRange;
          X[2] = avgFreq;
          
          // Account for sound from the speaker distorting the sound parameters, movement still readable
          if (!player.isPlaying()) {
            X[3] = windowRange[3];
            X[4] = windowSD[3];
          } else {
            X[3] = 0;
            X[4] = 0;
          }
          
          // Add data to arraylist visual for visualization
          visual.add(avgStdDev);
          

          if (!svmTrained) { //if the SVM model is not trained

            int Y = type; //Form a label Y;  // GIVEN LABEL FROM US WHEN TRAINING
            double[] dataToTrain = { X[0], X[1], X[2], X[3], X[4], Y }; //Form a dataToTrain with label Y (supervised label)    // ADD X[3], X[4] here if needed
            trainData.add(new Data(dataToTrain)); //Add the dataToTrain to the trainingData collection.
            appendArray(modeArray, Y); //append the label to  for visualization
            
            println("train:", Y);
            ++tCnt;
          } else { //if the SVM model is trained
            // PREDICTING

            double[] dataToTest = {X[0], X[1], X[2], X[3], X[4] }; //Form a dataToTest without label Y                    // ADD X[3], X[4] here if needed
            int predictedY = (int) svmPredict(dataToTest); //SVMPredict the label of the dataToTest
            lastPredY = predictedY; //update the lastPredY;
            appendArray(modeArray, predictedY); //append the prediction results to modeArray for visualization
           
            //println("PREDICTED LABEL:", predictedY);
          }
          b_featureReady = false; //reset the flag for the next update
        } else {
          if (!svmTrained) { //if the SVM model is not trained

            appendArray(modeArray, -1); //the class is null without mouse pressed.
          } else {

            appendArray(modeArray, lastPredY); //append the last prediction results to modeArray for visualization
          }
        }
      }


      /*********************************************************************************************************************************************************************/



      return;
    }
  }
}

// For starting to play a recording
void mousePressed() {
  
  // check if mouse is inside the bounding box of the ellipse
  
  // Loops through each recording
  int lengthBetween = width/visual.size() + 1;
  
  for (int i = 0; i < recIndex.size(); i++) {
  
    if (mouseX > (lengthBetween*recIndex.get(i)) - w && mouseX < (lengthBetween*recIndex.get(i)) + w && mouseY < 8*height/10 - h + h/2 && mouseY > 8*height/10 - h - h/2) {
      
      //println("X:" + mouseX + " Y:" + mouseY);
      if (buttonPressed) {
        // rewind and stop the recording
        //println("Stop playing");
        player.rewind();
        player.pause();
        green.set(i, false);
      
        // reset the button pressed to false
        buttonPressed = false;
       
      } else {
        
       // println("Start playing");
        player = minim.loadFile("babyvoice.wav");
        player.play();
        green.set(i, true);
        buttonPressed = true;
        
      }
    } 
  }
}

void keyPressed() {
  System.out.println("Pressed");

  if (key == ENTER) {
    if (tCnt>0 || type>0) {
      if (!firstTrained) firstTrained = true;
      resetSVM();
    } else {
      println("Error: No Data");
    }
  }
  if (key >= '0' && key <= '9') {
    type = key - '0';
  }
  if (key == TAB) {
    if (tCnt>0) { 
      if (type<(colors.length-1))++type;
      tCnt = 0;
    }
  }
  if (key == '/') {
    firstTrained = false;
    resetSVM();
    clearSVM();
  }
  if (key == 'S' || key == 's') {
    if (model!=null) { 
      saveSVM_Model(sketchPath()+"/data/test.model", model);
      println("Model Saved");
    }
  }
  if (key == ' ') {
    if (b_pause == true) b_pause = false;
    else b_pause = true;
  }
  if (key == 'A' || key == 'a') {
    activationThld = min(activationThld+10, 100);
  }
  if (key == 'Z' || key == 'z') {
    activationThld = max(activationThld-10, 10);
  }
}