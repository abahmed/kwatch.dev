"use strict";(self.webpackChunkkwatch=self.webpackChunkkwatch||[]).push([[3217],{3905:(e,t,n)=>{n.d(t,{Zo:()=>u,kt:()=>m});var a=n(7294);function o(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function r(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);t&&(a=a.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,a)}return n}function l(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?r(Object(n),!0).forEach((function(t){o(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):r(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function i(e,t){if(null==e)return{};var n,a,o=function(e,t){if(null==e)return{};var n,a,o={},r=Object.keys(e);for(a=0;a<r.length;a++)n=r[a],t.indexOf(n)>=0||(o[n]=e[n]);return o}(e,t);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);for(a=0;a<r.length;a++)n=r[a],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(o[n]=e[n])}return o}var p=a.createContext({}),c=function(e){var t=a.useContext(p),n=t;return e&&(n="function"==typeof e?e(t):l(l({},t),e)),n},u=function(e){var t=c(e.components);return a.createElement(p.Provider,{value:t},e.children)},s="mdxType",d={inlineCode:"code",wrapper:function(e){var t=e.children;return a.createElement(a.Fragment,{},t)}},k=a.forwardRef((function(e,t){var n=e.components,o=e.mdxType,r=e.originalType,p=e.parentName,u=i(e,["components","mdxType","originalType","parentName"]),s=c(n),k=o,m=s["".concat(p,".").concat(k)]||s[k]||d[k]||r;return n?a.createElement(m,l(l({ref:t},u),{},{components:n})):a.createElement(m,l({ref:t},u))}));function m(e,t){var n=arguments,o=t&&t.mdxType;if("string"==typeof e||o){var r=n.length,l=new Array(r);l[0]=k;var i={};for(var p in t)hasOwnProperty.call(t,p)&&(i[p]=t[p]);i.originalType=e,i[s]="string"==typeof e?e:o,l[1]=i;for(var c=2;c<r;c++)l[c]=n[c];return a.createElement.apply(null,l)}return a.createElement.apply(null,n)}k.displayName="MDXCreateElement"},9803:(e,t,n)=>{n.r(t),n.d(t,{assets:()=>p,contentTitle:()=>l,default:()=>d,frontMatter:()=>r,metadata:()=>i,toc:()=>c});var a=n(7462),o=(n(7294),n(3905));const r={sidebar_position:2,title:"Installation",description:"a guide to deploy kwatch on kubernetes cluster",keywords:["kwatch","kubernetes","install","deploy","cluster","monitoring"],pagination_next:null,pagination_prev:null},l="Installation",i={unversionedId:"installation",id:"installation",title:"Installation",description:"a guide to deploy kwatch on kubernetes cluster",source:"@site/docs/installation.md",sourceDirName:".",slug:"/installation",permalink:"/docs/installation",draft:!1,tags:[],version:"current",sidebarPosition:2,frontMatter:{sidebar_position:2,title:"Installation",description:"a guide to deploy kwatch on kubernetes cluster",keywords:["kwatch","kubernetes","install","deploy","cluster","monitoring"],pagination_next:null,pagination_prev:null},sidebar:"tutorialSidebar"},p={},c=[{value:"Step 1: Get Configuration",id:"step-1-get-configuration",level:3},{value:"Step 2: Apply Configuration",id:"step-2-apply-configuration",level:3},{value:"Step 3: Deploy kwatch",id:"step-3-deploy-kwatch",level:3}],u={toc:c},s="wrapper";function d(e){let{components:t,...n}=e;return(0,o.kt)(s,(0,a.Z)({},u,n,{components:t,mdxType:"MDXLayout"}),(0,o.kt)("h1",{id:"installation"},"Installation"),(0,o.kt)("p",null,"You can install kwatch into your kubernetes(k8s) cluster easily in one command"),(0,o.kt)("h3",{id:"step-1-get-configuration"},"Step 1: Get Configuration"),(0,o.kt)("p",null,"Get the configuration template"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-bash"},"curl  -L https://raw.githubusercontent.com/abahmed/kwatch/v0.8.3/deploy/config.yaml -o config.yaml\n")),(0,o.kt)("p",null,"Here is an example of the configuration file"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-yaml"},"apiVersion: v1\nkind: Namespace\nmetadata:\n  name: kwatch\n---\napiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: kwatch\n  namespace: kwatch\ndata:\n  config.yaml: |\n    maxRecentLogLines: <optional_number_of_lines>\n    ignoreFailedGracefulShutdown: <optional_boolean>\n    alert:\n      slack:\n        webhook: <webhook_url>\n      pagerduty:\n        integrationKey: <integration_key>\n      discord:\n        webhook: <webhook_url>\n      telegram:\n          token: <token_key>\n          chatId: <chat_id>\n      teams:\n          webhook: <webhook_url>\n      rocketchat:\n          webhook: <webhook_url>\n      mattermost:\n          webhook: <webhook_url>\n      opsgenie:\n        apiKey: <api_key>\n    namespaces:\n      - <optional_namespace>\n")),(0,o.kt)("p",null,"It contains full configurations that kwatch might have."),(0,o.kt)("p",null,(0,o.kt)("strong",{parentName:"p"},"you don't need to use all of them, check ",(0,o.kt)("a",{parentName:"strong",href:"./general-configuration"},"General Configuration")," and ",(0,o.kt)("a",{parentName:"strong",href:"./channels"},"Channels"))),(0,o.kt)("p",null,"You need to update, or remove ",(0,o.kt)("inlineCode",{parentName:"p"},"<...>")," this with your configuration and ",(0,o.kt)("strong",{parentName:"p"},"remove unused configs")),(0,o.kt)("h3",{id:"step-2-apply-configuration"},"Step 2: Apply Configuration"),(0,o.kt)("p",null,"Apply your configuration"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-bash"},"kubectl apply -f config.yaml\n")),(0,o.kt)("h3",{id:"step-3-deploy-kwatch"},"Step 3: Deploy kwatch"),(0,o.kt)("p",null,"Deploy kwatch on your cluster with one command"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-bash"},"kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.8.3/deploy/deploy.yaml\n")))}d.isMDXComponent=!0}}]);