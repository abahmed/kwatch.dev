"use strict";(self.webpackChunkkwatch=self.webpackChunkkwatch||[]).push([[2293],{3905:(e,t,n)=>{n.d(t,{Zo:()=>m,kt:()=>f});var r=n(7294);function a(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function i(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,r)}return n}function o(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?i(Object(n),!0).forEach((function(t){a(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):i(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function l(e,t){if(null==e)return{};var n,r,a=function(e,t){if(null==e)return{};var n,r,a={},i=Object.keys(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||(a[n]=e[n]);return a}(e,t);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(a[n]=e[n])}return a}var c=r.createContext({}),p=function(e){var t=r.useContext(c),n=t;return e&&(n="function"==typeof e?e(t):o(o({},t),e)),n},m=function(e){var t=p(e.components);return r.createElement(c.Provider,{value:t},e.children)},s="mdxType",d={inlineCode:"code",wrapper:function(e){var t=e.children;return r.createElement(r.Fragment,{},t)}},u=r.forwardRef((function(e,t){var n=e.components,a=e.mdxType,i=e.originalType,c=e.parentName,m=l(e,["components","mdxType","originalType","parentName"]),s=p(n),u=a,f=s["".concat(c,".").concat(u)]||s[u]||d[u]||i;return n?r.createElement(f,o(o({ref:t},m),{},{components:n})):r.createElement(f,o({ref:t},m))}));function f(e,t){var n=arguments,a=t&&t.mdxType;if("string"==typeof e||a){var i=n.length,o=new Array(i);o[0]=u;var l={};for(var c in t)hasOwnProperty.call(t,c)&&(l[c]=t[c]);l.originalType=e,l[s]="string"==typeof e?e:a,o[1]=l;for(var p=2;p<i;p++)o[p]=n[p];return r.createElement.apply(null,o)}return r.createElement.apply(null,n)}u.displayName="MDXCreateElement"},9178:(e,t,n)=>{n.r(t),n.d(t,{assets:()=>c,contentTitle:()=>o,default:()=>d,frontMatter:()=>i,metadata:()=>l,toc:()=>p});var r=n(7462),a=(n(7294),n(3905));const i={sidebar_position:9,title:"Matrix",description:"kwatch configuration for matrix",keywords:["kwatch","matrix","monitor","detect","crash","kubernetes","cluster"],pagination_next:null,pagination_prev:null},o="Matrix",l={unversionedId:"channels/matrix",id:"channels/matrix",title:"Matrix",description:"kwatch configuration for matrix",source:"@site/docs/channels/matrix.md",sourceDirName:"channels",slug:"/channels/matrix",permalink:"/docs/channels/matrix",draft:!1,tags:[],version:"current",sidebarPosition:9,frontMatter:{sidebar_position:9,title:"Matrix",description:"kwatch configuration for matrix",keywords:["kwatch","matrix","monitor","detect","crash","kubernetes","cluster"],pagination_next:null,pagination_prev:null},sidebar:"tutorialSidebar"},c={},p=[{value:"Configuration",id:"configuration",level:3},{value:"Example",id:"example",level:3},{value:"Screenshot",id:"screenshot",level:3}],m={toc:p},s="wrapper";function d(e){let{components:t,...n}=e;return(0,a.kt)(s,(0,r.Z)({},m,n,{components:t,mdxType:"MDXLayout"}),(0,a.kt)("h1",{id:"matrix"},"Matrix"),(0,a.kt)("p",null,"If you want to enable Matrix, provide homeServer, accessToken and internalRoomID\nwith optional text and title"),(0,a.kt)("h3",{id:"configuration"},"Configuration"),(0,a.kt)("table",null,(0,a.kt)("thead",{parentName:"table"},(0,a.kt)("tr",{parentName:"thead"},(0,a.kt)("th",{parentName:"tr",align:"left"},"Parameter"),(0,a.kt)("th",{parentName:"tr",align:"left"},"Description"))),(0,a.kt)("tbody",{parentName:"table"},(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.matrix.homeServer")),(0,a.kt)("td",{parentName:"tr",align:"left"},"HomeServer URL")),(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.matrix.accessToken")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Account access token")),(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.matrix.internalRoomID")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Internal room ID")),(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.matrix.title")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Customized title in message")),(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.matrix.text")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Customized text in message")))),(0,a.kt)("h3",{id:"example"},"Example"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-yaml"},"apiVersion: v1\nkind: Namespace\nmetadata:\n  name: kwatch\n---\napiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: kwatch\n  namespace: kwatch\ndata:\n  config.yaml: |\n    alert:\n      matrix:\n        accessToken: ACCESS_TOKEN\n")),(0,a.kt)("h3",{id:"screenshot"},"Screenshot"),(0,a.kt)("p",{align:"center"},(0,a.kt)("img",{src:"./../../img/matrix.png","max-height":"700px"})))}d.isMDXComponent=!0}}]);