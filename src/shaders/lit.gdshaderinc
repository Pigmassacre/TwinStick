// The light of the mine: stepped, in bands, and dithered between them, so it
// is drawn in pixels like everything it falls on.
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float bayer(vec2 frag) {
	int x = int(frag.x) % 4;
	int y = int(frag.y) % 4;
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

// The dither only blurs the edge between bands a little: most of the floor is flatly one band or the next.
float stepped(float v, vec2 frag, float bands) {
	return floor(v * bands + 0.5 + (bayer(frag) - 0.5) * 0.7) / bands;
}

// A lamp's light with distance: the falloff is shaped here, so the engine's is
// left off (omni_attenuation = 0), which would need world units of another size.
float falloff(float attenuation) {
	return attenuation * attenuation * sqrt(attenuation);
}
