# VisionMate IEEE Submission Checklist

## A. Manuscript Structure
- Title is specific, technical, and not marketing-heavy.
- Abstract includes problem, method, novelty, and outcome.
- Index terms are 4 to 8 terms and alphabetically sorted.
- Introduction states research gap and contributions clearly.
- Related work compares your method with prior approaches.
- Methods section includes equations and threshold details.
- Experimental setup is reproducible.
- Results include both quantitative and qualitative evidence.
- Limitations and threats to validity are explicitly stated.
- Conclusion summarizes contribution without repeating abstract.

## B. VisionMate-Specific Technical Completeness
- Dual-zone logic is explicitly documented: frontal risk and lower path risk.
- Distance narration policy is described (near, medium, far).
- Path-clear recovery announcement behavior is documented.
- Face recognition pipeline (embedding generation and matching) is explained.
- Fall workflow and SOS escalation logic are explained.
- Battery-critical SOS policy and cooldown are explained.
- Offline versus online feature partition is clearly stated.

## C. Quantitative Results Required Before Submission
- Object detection precision and recall reported.
- Path blocked-to-clear transition F1 reported.
- Face TAR, FAR, and FRR reported.
- Navigation completion rate and timing error reported.
- SOS trigger delay and false alarm rate reported.
- Runtime latency (frame to alert) reported.
- Device battery drain per hour reported.

## D. Figures and Tables
- System architecture diagram included.
- End-to-end runtime flow diagram included.
- At least one qualitative example of blocked-to-clear transition included.
- At least one table compares VisionMate against baseline tools.
- All figure axes have units and readable labels.
- Figure captions are below figures.
- Table titles are above tables.

## E. Writing and Style
- No informal language.
- Acronyms are defined at first use.
- Claims are evidence-backed and not exaggerated.
- No contradictions between abstract, results, and conclusion.
- Grammar and punctuation are proofread.

## F. Privacy, Ethics, and Safety
- Consent policy for guardian sync is stated.
- Data minimization policy is stated.
- Face data handling policy is stated (embedding versus raw image).
- Safety disclaimer is included (assistive aid, not medical replacement).
- Failure modes and fallback behavior are documented.

## G. IEEE Compliance
- Two-column IEEE template formatting applied in final Word file.
- References are in IEEE format with complete publication details.
- All in-text citations are matched in references.
- Author bios for all authors are included.
- Corresponding author details are complete.
- Final PDF generated with a compatible workflow.

## H. Final Quality Gate
- One internal technical reviewer signs off methods and results.
- One language reviewer signs off clarity and grammar.
- One accessibility reviewer validates user-centered claims.
- Final manuscript and clean source package archived.
