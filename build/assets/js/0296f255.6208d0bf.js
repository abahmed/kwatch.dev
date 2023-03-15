"use strict";(self.webpackChunkkwatch=self.webpackChunkkwatch||[]).push([[5907],{3905:(e,t,n)=>{n.d(t,{Zo:()=>s,kt:()=>d});var r=n(7294);function a(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function i(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,r)}return n}function o(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?i(Object(n),!0).forEach((function(t){a(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):i(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function p(e,t){if(null==e)return{};var n,r,a=function(e,t){if(null==e)return{};var n,r,a={},i=Object.keys(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||(a[n]=e[n]);return a}(e,t);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(a[n]=e[n])}return a}var l=r.createContext({}),c=function(e){var t=r.useContext(l),n=t;return e&&(n="function"==typeof e?e(t):o(o({},t),e)),n},s=function(e){var t=c(e.components);return r.createElement(l.Provider,{value:t},e.children)},u="mdxType",g={inlineCode:"code",wrapper:function(e){var t=e.children;return r.createElement(r.Fragment,{},t)}},m=r.forwardRef((function(e,t){var n=e.components,a=e.mdxType,i=e.originalType,l=e.parentName,s=p(e,["components","mdxType","originalType","parentName"]),u=c(n),m=a,d=u["".concat(l,".").concat(m)]||u[m]||g[m]||i;return n?r.createElement(d,o(o({ref:t},s),{},{components:n})):r.createElement(d,o({ref:t},s))}));function d(e,t){var n=arguments,a=t&&t.mdxType;if("string"==typeof e||a){var i=n.length,o=new Array(i);o[0]=m;var p={};for(var l in t)hasOwnProperty.call(t,l)&&(p[l]=t[l]);p.originalType=e,p[u]="string"==typeof e?e:a,o[1]=p;for(var c=2;c<i;c++)o[c]=n[c];return r.createElement.apply(null,o)}return r.createElement.apply(null,n)}m.displayName="MDXCreateElement"},6363:(e,t,n)=>{n.r(t),n.d(t,{assets:()=>l,contentTitle:()=>o,default:()=>g,frontMatter:()=>i,metadata:()=>p,toc:()=>c});var r=n(7462),a=(n(7294),n(3905));const i={sidebar_position:8,title:"Opsgenie",description:"kwatch configuration for opsgenie",keywords:["kwatch","opsgenie","monitor","detect","crash","kubernetes","cluster"],pagination_next:null,pagination_prev:null},o="Opsgenie",p={unversionedId:"channels/opsgenie",id:"channels/opsgenie",title:"Opsgenie",description:"kwatch configuration for opsgenie",source:"@site/docs/channels/opsgenie.md",sourceDirName:"channels",slug:"/channels/opsgenie",permalink:"/docs/channels/opsgenie",draft:!1,tags:[],version:"current",sidebarPosition:8,frontMatter:{sidebar_position:8,title:"Opsgenie",description:"kwatch configuration for opsgenie",keywords:["kwatch","opsgenie","monitor","detect","crash","kubernetes","cluster"],pagination_next:null,pagination_prev:null},sidebar:"tutorialSidebar"},l={},c=[{value:"Configuration",id:"configuration",level:3},{value:"Example",id:"example",level:3},{value:"Screenshot",id:"screenshot",level:3}],s={toc:c},u="wrapper";function g(e){let{components:t,...n}=e;return(0,a.kt)(u,(0,r.Z)({},s,n,{components:t,mdxType:"MDXLayout"}),(0,a.kt)("h1",{id:"opsgenie"},"Opsgenie"),(0,a.kt)("p",null,"If you want to enable Opsgenie, provide the API key"),(0,a.kt)("h3",{id:"configuration"},"Configuration"),(0,a.kt)("table",null,(0,a.kt)("thead",{parentName:"table"},(0,a.kt)("tr",{parentName:"thead"},(0,a.kt)("th",{parentName:"tr",align:"left"},"Parameter"),(0,a.kt)("th",{parentName:"tr",align:"left"},"Description"))),(0,a.kt)("tbody",{parentName:"table"},(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.opsgenie.apiKey")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Opsgenie API Key")),(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.opsgenie.title")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Customized title in Opsgenie message")),(0,a.kt)("tr",{parentName:"tbody"},(0,a.kt)("td",{parentName:"tr",align:"left"},(0,a.kt)("inlineCode",{parentName:"td"},"alert.opsgenie.text")),(0,a.kt)("td",{parentName:"tr",align:"left"},"Customized text in Opsgenie message")))),(0,a.kt)("h3",{id:"example"},"Example"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-yaml"},"apiVersion: v1\nkind: Namespace\nmetadata:\n  name: kwatch\n---\napiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: kwatch\n  namespace: kwatch\ndata:\n  config.yaml: |\n    alert:\n      opsgenie:\n        apiKey: API_KEY\n")),(0,a.kt)("h3",{id:"screenshot"},"Screenshot"),(0,a.kt)("p",{align:"center"},(0,a.kt)("img",{src:"./../../img/opsgenie.png","max-height":"700px"})))}g.isMDXComponent=!0}}]);