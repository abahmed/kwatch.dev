"use strict";(self.webpackChunkkwatch=self.webpackChunkkwatch||[]).push([[1919],{3905:(e,t,a)=>{a.d(t,{Zo:()=>p,kt:()=>b});var r=a(7294);function n(e,t,a){return t in e?Object.defineProperty(e,t,{value:a,enumerable:!0,configurable:!0,writable:!0}):e[t]=a,e}function l(e,t){var a=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),a.push.apply(a,r)}return a}function o(e){for(var t=1;t<arguments.length;t++){var a=null!=arguments[t]?arguments[t]:{};t%2?l(Object(a),!0).forEach((function(t){n(e,t,a[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(a)):l(Object(a)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(a,t))}))}return e}function i(e,t){if(null==e)return{};var a,r,n=function(e,t){if(null==e)return{};var a,r,n={},l=Object.keys(e);for(r=0;r<l.length;r++)a=l[r],t.indexOf(a)>=0||(n[a]=e[a]);return n}(e,t);if(Object.getOwnPropertySymbols){var l=Object.getOwnPropertySymbols(e);for(r=0;r<l.length;r++)a=l[r],t.indexOf(a)>=0||Object.prototype.propertyIsEnumerable.call(e,a)&&(n[a]=e[a])}return n}var s=r.createContext({}),h=function(e){var t=r.useContext(s),a=t;return e&&(a="function"==typeof e?e(t):o(o({},t),e)),a},p=function(e){var t=h(e.components);return r.createElement(s.Provider,{value:t},e.children)},u="mdxType",c={inlineCode:"code",wrapper:function(e){var t=e.children;return r.createElement(r.Fragment,{},t)}},m=r.forwardRef((function(e,t){var a=e.components,n=e.mdxType,l=e.originalType,s=e.parentName,p=i(e,["components","mdxType","originalType","parentName"]),u=h(a),m=n,b=u["".concat(s,".").concat(m)]||u[m]||c[m]||l;return a?r.createElement(b,o(o({ref:t},p),{},{components:a})):r.createElement(b,o({ref:t},p))}));function b(e,t){var a=arguments,n=t&&t.mdxType;if("string"==typeof e||n){var l=a.length,o=new Array(l);o[0]=m;var i={};for(var s in t)hasOwnProperty.call(t,s)&&(i[s]=t[s]);i.originalType=e,i[u]="string"==typeof e?e:n,o[1]=i;for(var h=2;h<l;h++)o[h]=a[h];return r.createElement.apply(null,o)}return r.createElement.apply(null,a)}m.displayName="MDXCreateElement"},5690:(e,t,a)=>{a.r(t),a.d(t,{assets:()=>s,contentTitle:()=>o,default:()=>c,frontMatter:()=>l,metadata:()=>i,toc:()=>h});var r=a(7462),n=(a(7294),a(3905));const l={slug:"release-v0-5-0",title:"v0.5.0 is released!",authors:["abahmed"],tags:["kwatch","kubernetes","devops","monitoring","release"],keywords:["kwatch","kubernetes","devops","monitoring","release","cluster","crash","v0.5.0"],description:"monitor all changes in your Kubernetes cluster & detects crashes in your running apps in real time",pagination_prev:null},o=void 0,i={permalink:"/blog/release-v0-5-0",source:"@site/blog/2022-03-19-release-v0-5-0.mdx",title:"v0.5.0 is released!",description:"monitor all changes in your Kubernetes cluster & detects crashes in your running apps in real time",date:"2022-03-19T00:00:00.000Z",formattedDate:"March 19, 2022",tags:[{label:"kwatch",permalink:"/blog/tags/kwatch"},{label:"kubernetes",permalink:"/blog/tags/kubernetes"},{label:"devops",permalink:"/blog/tags/devops"},{label:"monitoring",permalink:"/blog/tags/monitoring"},{label:"release",permalink:"/blog/tags/release"}],readingTime:.87,hasTruncateMarker:!0,authors:[{name:"Abdelrahman Ahmed",title:"Owner of kwatch",url:"https://github.com/abahmed",imageURL:"https://github.com/abahmed.png",key:"abahmed"}],frontMatter:{slug:"release-v0-5-0",title:"v0.5.0 is released!",authors:["abahmed"],tags:["kwatch","kubernetes","devops","monitoring","release"],keywords:["kwatch","kubernetes","devops","monitoring","release","cluster","crash","v0.5.0"],description:"monitor all changes in your Kubernetes cluster & detects crashes in your running apps in real time",pagination_prev:null},prevItem:{title:"v0.6.0 is released!",permalink:"/blog/release-v0-6-0"},nextItem:{title:"v0.4.0 is released!",permalink:"/blog/release-v0-4-0"}},s={authorsImageUrls:[void 0]},h=[{value:"\ud83d\ude80 What&#39;s New",id:"-whats-new",level:2},{value:"\ud83e\uddf0 Maintenance",id:"-maintenance",level:2},{value:"\u2b06\ufe0f How to Upgrade",id:"\ufe0f-how-to-upgrade",level:2},{value:"\ud83c\udf1f New Contributors",id:"-new-contributors",level:2}],p={toc:h},u="wrapper";function c(e){let{components:t,...a}=e;return(0,n.kt)(u,(0,r.Z)({},p,a,{components:t,mdxType:"MDXLayout"}),(0,n.kt)("p",null,"We are glad to announce that ",(0,n.kt)("a",{parentName:"p",href:"https://github.com/abahmed/kwatch/releases/tag/v0.5.0"},"v0.5.0")," of kwatch is released! \ud83c\udf89\ud83c\udf89\ud83c\udf89"),(0,n.kt)("h2",{id:"-whats-new"},"\ud83d\ude80 What's New"),(0,n.kt)("ul",null,(0,n.kt)("li",{parentName:"ul"},"Use slack blocks in slack handler by ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/simonfrey"},"@simonfrey")," in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/63"},"https://github.com/abahmed/kwatch/pull/63")),(0,n.kt)("li",{parentName:"ul"},"Feature/allow to disable update check by ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/simonfrey"},"@simonfrey")," in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/67"},"https://github.com/abahmed/kwatch/pull/67")),(0,n.kt)("li",{parentName:"ul"},"Add namespace forbid list, to allow all namespaces except certain ones by ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/simonfrey"},"@simonfrey")," in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/70"},"https://github.com/abahmed/kwatch/pull/70"))),(0,n.kt)("h2",{id:"-maintenance"},"\ud83e\uddf0 Maintenance"),(0,n.kt)("ul",null,(0,n.kt)("li",{parentName:"ul"},"\u2b06\ufe0f Bump github.com/slack-go/slack from 0.10.1 to 0.10.2 by @dependabot in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/69"},"https://github.com/abahmed/kwatch/pull/69")),(0,n.kt)("li",{parentName:"ul"},"add(Helm): by @yaskinny in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/74"},"https://github.com/abahmed/kwatch/pull/74")),(0,n.kt)("li",{parentName:"ul"},"\u2b06\ufe0f Bump k8s.io/client-go from 0.23.3 to 0.23.4 by @dependabot in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/73"},"https://github.com/abahmed/kwatch/pull/73")),(0,n.kt)("li",{parentName:"ul"},"\u2b06\ufe0f Bump github.com/bwmarrin/discordgo from 0.23.2 to 0.24.0 by @dependabot in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/77"},"https://github.com/abahmed/kwatch/pull/77")),(0,n.kt)("li",{parentName:"ul"},"\u2b06\ufe0f Bump k8s.io/client-go from 0.23.4 to 0.23.5 by @dependabot in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/80"},"https://github.com/abahmed/kwatch/pull/80"))),(0,n.kt)("h2",{id:"\ufe0f-how-to-upgrade"},"\u2b06\ufe0f How to Upgrade"),(0,n.kt)("p",null,"There are no breaking changes, just deploy the new version from any previous version using"),(0,n.kt)("pre",null,(0,n.kt)("code",{parentName:"pre",className:"language-shell"},"kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.5.0/deploy/deploy.yaml\n")),(0,n.kt)("h2",{id:"-new-contributors"},"\ud83c\udf1f New Contributors"),(0,n.kt)("ul",null,(0,n.kt)("li",{parentName:"ul"},(0,n.kt)("a",{parentName:"li",href:"https://github.com/romualdofernandes"},"@romualdofernandes")," made their first contribution in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/45"},"https://github.com/abahmed/kwatch/pull/45")),(0,n.kt)("li",{parentName:"ul"},(0,n.kt)("a",{parentName:"li",href:"https://github.com/dependabot"},"@dependabot"),"made their first contribution in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/46"},"https://github.com/abahmed/kwatch/pull/46")),(0,n.kt)("li",{parentName:"ul"},(0,n.kt)("a",{parentName:"li",href:"https://github.com/simonfrey"},"@simonfrey")," made their first contribution in ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/abahmed/kwatch/pull/54"},"https://github.com/abahmed/kwatch/pull/54"))),(0,n.kt)("p",null,(0,n.kt)("strong",{parentName:"p"},"If you like kwatch, give it a star on ",(0,n.kt)("a",{parentName:"strong",href:"https://github.com/abahmed/kwatch"},"GitHub"),"!")))}c.isMDXComponent=!0}}]);