// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyBlK84XL2k4OVaT23Wp8DzYDC5_VZXzwMc",
  authDomain: "vista-ci.firebaseapp.com",
  projectId: "vista-ci",
  storageBucket: "vista-ci.firebasestorage.app",
  messagingSenderId: "1087429884658",
  appId: "1:1087429884658:web:8126ffe32636f5651a6e6b",
  measurementId: "G-FQW25SN4PF"
};

// Initialize Firebase
export const firebaseApp = initializeApp(firebaseConfig);
export const auth = getAuth(firebaseApp);
export const db = getFirestore(firebaseApp);