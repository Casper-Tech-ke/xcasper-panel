{{-- Shared XCASPER animated Casper background — included in every layout --}}
@php $xcasper = \Pterodactyl\Http\Controllers\SuperAdminController::getConfig(); @endphp

@if($xcasper['bg_image_url'])
{{-- ── Image background override ────────────────────────── --}}
<style>
    html, body {
        background-image: url('{{ $xcasper['bg_image_url'] }}') !important;
        background-size: cover !important;
        background-position: center !important;
        background-attachment: fixed !important;
        background-color: {{ $xcasper['bg_color'] }} !important;
    }
</style>
@else
{{-- ── Canvas Casper animation background ───────────────── --}}
<canvas id="xcasper-global-bg" style="position:fixed;top:0;left:0;width:100%;height:100%;z-index:-1;pointer-events:none;"></canvas>
<style>
    html { background: {{ $xcasper['bg_color'] }}; }
</style>
<script>
(function () {
    var canvas = document.getElementById('xcasper-global-bg');
    if (!canvas) return;
    var ctx = canvas.getContext('2d');
    var W, H, t = 0;

    var PRIMARY = '{{ $xcasper['primary_color'] }}';
    var BG      = '{{ $xcasper['bg_color'] }}';

    var stars = Array.from({length: 160}, function() {
        return {
            x: Math.random(), y: Math.random(),
            r: Math.random() * 1.4 + 0.3,
            s: Math.random() * 0.02 + 0.004
        };
    });

    var particles = Array.from({length: 35}, function() {
        return {
            x: Math.random(), y: Math.random(),
            vx: (Math.random()-.5)*.00028, vy: (Math.random()-.5)*.00028,
            r: Math.random()*2.5+1,
            alpha: Math.random()*.4+.08,
            hue: Math.random() > .5 ? 190 : 270
        };
    });

    function resize() {
        W = canvas.width  = window.innerWidth;
        H = canvas.height = window.innerHeight;
    }
    window.addEventListener('resize', resize);
    resize();

    /* ── Draw one Casper ghost ── */
    function drawCasper(cx, cy, scale, time) {
        var s = scale;
        ctx.save();
        ctx.translate(cx, cy + Math.sin(time * .7) * 10);

        /* glow */
        var aura = ctx.createRadialGradient(0,-s*.1,s*.15, 0,-s*.1,s*.9);
        aura.addColorStop(0, 'rgba(0,212,255,0.14)');
        aura.addColorStop(.5,'rgba(124,58,237,0.07)');
        aura.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.beginPath();
        ctx.ellipse(0,-s*.05,s*.85,s*.95,0,0,Math.PI*2);
        ctx.fillStyle = aura;
        ctx.fill();

        /* body */
        var bodyGrad = ctx.createLinearGradient(-s*.5,-s*.6,s*.4,s*.5);
        bodyGrad.addColorStop(0,'#dff4ff');
        bodyGrad.addColorStop(.4,'#b8e8ff');
        bodyGrad.addColorStop(1,'#8ac8e8');

        var wave = Math.sin(time*.8)*s*.04;
        ctx.beginPath();
        ctx.moveTo(-s*.38, s*.2);
        ctx.bezierCurveTo(-s*.38,s*.38+wave, -s*.22,s*.44+wave, -s*.12,s*.38+wave);
        ctx.bezierCurveTo(-s*.02,s*.32+wave,  s*.02,s*.5+wave,   s*.12,s*.4+wave);
        ctx.bezierCurveTo( s*.22,s*.3+wave,   s*.26,s*.44+wave,  s*.38,s*.38+wave);
        ctx.bezierCurveTo( s*.38,s*.2,  s*.45,-s*.55, 0,-s*.6);
        ctx.bezierCurveTo(-s*.45,-s*.55,-s*.38,s*.0,-s*.38,s*.2);
        ctx.closePath();
        ctx.fillStyle = bodyGrad;
        ctx.fill();
        ctx.strokeStyle = 'rgba(180,220,255,0.35)';
        ctx.lineWidth = 1.2;
        ctx.stroke();

        /* sheen */
        ctx.beginPath();
        ctx.ellipse(-s*.1,-s*.25,s*.11,s*.2,-0.3,0,Math.PI*2);
        var sheen = ctx.createRadialGradient(-s*.12,-s*.28,0,-s*.12,-s*.28,s*.18);
        sheen.addColorStop(0,'rgba(255,255,255,0.6)');
        sheen.addColorStop(1,'rgba(255,255,255,0)');
        ctx.fillStyle = sheen;
        ctx.fill();

        /* eyes */
        var eyeY = -s*.18;
        var blink = s*.14*(0.5+0.5*Math.abs(Math.sin(time*.3)));
        [-s*.15, s*.15].forEach(function(ex) {
            ctx.beginPath();
            ctx.ellipse(ex,eyeY,s*.09,blink,0,0,Math.PI*2);
            ctx.fillStyle='#1a2744'; ctx.fill();
            ctx.beginPath();
            ctx.arc(ex+s*.04,eyeY-blink*.3,s*.03,0,Math.PI*2);
            ctx.fillStyle='#ffffff'; ctx.fill();
        });

        /* blush */
        ctx.beginPath();
        ctx.ellipse(-s*.24,-s*.08,s*.065,s*.022,0,0,Math.PI*2);
        ctx.fillStyle='rgba(255,160,180,0.4)'; ctx.fill();
        ctx.beginPath();
        ctx.ellipse( s*.24,-s*.08,s*.065,s*.022,0,0,Math.PI*2);
        ctx.fill();

        /* smile */
        ctx.beginPath();
        ctx.arc(0,s*.02,s*.09,0.2,Math.PI-.2);
        ctx.strokeStyle='#1a2744'; ctx.lineWidth=2; ctx.lineCap='round'; ctx.stroke();

        /* sparkles */
        [{a:time*.5,r:s*.55,sz:s*.038},{a:time*.3+2,r:s*.65,sz:s*.028},{a:-time*.4+4,r:s*.5,sz:s*.022}]
        .forEach(function(sp){
            var sx=Math.cos(sp.a)*sp.r, sy=Math.sin(sp.a)*sp.r*.6;
            ctx.save(); ctx.translate(sx,sy); ctx.rotate(sp.a);
            ctx.beginPath();
            for(var i=0;i<4;i++){
                ctx.lineTo(0,-sp.sz); ctx.rotate(Math.PI/4);
                ctx.lineTo(0,-sp.sz*.38); ctx.rotate(Math.PI/4);
            }
            ctx.closePath();
            ctx.fillStyle='rgba(0,212,255,'+(0.45+0.4*Math.sin(time+sp.a))+')';
            ctx.fill(); ctx.restore();
        });

        ctx.restore();
    }

    function frame() {
        t += 0.016;
        ctx.clearRect(0,0,W,H);

        /* sky */
        var bg = ctx.createRadialGradient(W/2,H/2,0,W/2,H/2,Math.max(W,H)*.8);
        bg.addColorStop(0,  'rgba(11,23,56,1)');
        bg.addColorStop(.5, 'rgba(5,13,31,1)');
        bg.addColorStop(1,  'rgba(26,5,51,1)');
        ctx.fillStyle = bg;
        ctx.fillRect(0,0,W,H);

        /* grid */
        ctx.save();
        ctx.strokeStyle='rgba(0,212,255,0.035)'; ctx.lineWidth=1;
        for(var x=0;x<W;x+=64){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,H);ctx.stroke();}
        for(var y=0;y<H;y+=64){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke();}
        ctx.restore();

        /* stars */
        stars.forEach(function(st){
            ctx.beginPath();
            ctx.arc(st.x*W,st.y*H,st.r,0,Math.PI*2);
            ctx.fillStyle='rgba(200,230,255,'+(0.25+0.55*Math.abs(Math.sin(t*st.s*10)))+')';
            ctx.fill();
        });

        /* particles */
        particles.forEach(function(p){
            p.x+=p.vx; p.y+=p.vy;
            if(p.x<0)p.x=1; if(p.x>1)p.x=0;
            if(p.y<0)p.y=1; if(p.y>1)p.y=0;
            ctx.beginPath();
            ctx.arc(p.x*W,p.y*H,p.r,0,Math.PI*2);
            ctx.fillStyle='hsla('+p.hue+',100%,70%,'+p.alpha+')';
            ctx.fill();
        });

        /* main Casper — tucked into bottom-right corner, purely decorative */
        var mainS = Math.min(W,H) * 0.13;
        ctx.globalAlpha = 0.28;
        drawCasper(W - mainS*0.62, H - mainS*0.42, mainS, t);

        /* small accent ghost — top left */
        var sideS = mainS * 0.45;
        ctx.globalAlpha = 0.13;
        drawCasper(sideS * 0.7, sideS * 0.7, sideS, t + 2);

        ctx.globalAlpha = 1;
        requestAnimationFrame(frame);
    }
    frame();
})();
</script>
@endif
