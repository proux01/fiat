Require Import Program.
Require Import FMapInterface.
Require Import FMapAVL OrderedTypeEx.
Require Import Coq.FSets.FMapFacts.
Require Import FMapExtensions.
Require Import AdditionalLemmas.

Unset Implicit Arguments.

Definition flatten {A} :=
  @List.fold_right (list A) (list A) (@List.app A) [].

Lemma in_flatten_iff :
  forall {A} x seqs, 
    @List.In A x (flatten seqs) <-> 
    exists seq, List.In seq seqs /\ List.In x seq.
Proof.
  intros; unfold flatten.
  induction seqs; simpl. 

  firstorder.
  rewrite in_app_iff.
  rewrite IHseqs.

  split.
  intros [ in_head | [seq (in_seqs & in_seq) ] ]; eauto.
  intros [ seq ( [ eq_head | in_seqs ] & in_seq ) ]; subst; eauto.
Qed.

Require Import SetEq.

Definition BagInsertEnumerate
           {TContainer TItem: Type}
           (benumerate : TContainer -> list TItem)
           (binsert    : TContainer -> TItem -> TContainer) :=
  forall item inserted container,
    List.In item (benumerate (binsert container inserted)) <->
    List.In item (benumerate container) \/ item = inserted.
    
Definition BagEnumerateEmpty
           {TContainer TItem: Type}
           (benumerate : TContainer -> list TItem)
           (bempty     : TContainer) :=
  forall item, ~ List.In item (benumerate bempty).

Definition BagFindStar
           {TContainer TItem TSearchTerm: Type}
           (bfind : TContainer -> TSearchTerm -> list TItem)
           (benumerate : TContainer -> list TItem)
           (bstar : TSearchTerm) :=
  forall container, bfind container bstar = benumerate container.

Definition BagFindCorrect
           {TContainer TItem TSearchTerm: Type}
           (bfind         : TContainer -> TSearchTerm -> list TItem)
           (bfind_matcher : TSearchTerm -> TItem -> bool)
           (benumerate : TContainer -> list TItem) :=
  forall container search_term,
    SetEq
      (List.filter (bfind_matcher search_term) (benumerate container))
      (bfind container search_term).

Class Bag (TContainer TItem TSearchTerm: Type) :=
  {
    bempty        : TContainer;
    bstar         : TSearchTerm;
    bfind_matcher : TSearchTerm -> TItem -> bool;

    benumerate : TContainer -> list TItem;
    bfind      : TContainer -> TSearchTerm -> list TItem;
    binsert    : TContainer -> TItem -> TContainer;
    
    binsert_enumerate : BagInsertEnumerate benumerate binsert;
    benumerate_empty  : BagEnumerateEmpty benumerate bempty;
    bfind_star        : BagFindStar bfind benumerate bstar;
    bfind_correct     : BagFindCorrect bfind bfind_matcher benumerate
  }.

Record BagPlusBagProof {TItem} :=
  { BagType: Type; 
    SearchTermType: Type; 
    BagProof: Bag BagType TItem SearchTermType }.

Module IndexedTree (Import M: WS).
  Module Import BasicFacts := WFacts_fun E M.
  Module Import BasicProperties := WProperties_fun E M.
  Module Import MoreFacts := FMapExtensions_fun E M.

  Definition TKey := key.

  Definition IndexedBagConsistency 
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm}
             projection fmap :=
    forall (key: TKey) (bag: TBag),
      MapsTo key bag fmap -> 
      forall (item: TItem),
        List.In item (benumerate bag) ->
        E.eq (projection item) key.

  Record IndexedBag 
         {TBag TItem TBagSearchTerm: Type} 
         {bags_bag: Bag TBag TItem TBagSearchTerm} 
         {projection} :=
    { 
      ifmap        : t TBag;
      iconsistency : IndexedBagConsistency projection ifmap
    }.

  Definition KeyFilter 
             {TItem}
             (key: TKey)
             (projection: TItem -> TKey) :=
    (fun x : TItem => if E.eq_dec (projection x) key then true else false).
  
  Lemma KeyFilter_beq :
    forall {TItem} beq,
      (forall x y, reflect (E.eq x y) (beq x y)) ->
      (forall key projection (item: TItem), 
         KeyFilter key projection item = beq (projection item) key).
  Proof.
    intros TItem beq spec key projection item.
    specialize (spec (projection item) key).
    unfold KeyFilter.
    destruct spec as [ is_eq | neq ];
    destruct (F.eq_dec _ _); intuition.
  Qed.    

  Lemma iconsistency_empty :
    forall {TBag TItem TBagSearchTerm: Type} 
           {bags_bag: Bag TBag TItem TBagSearchTerm} 
           projection,
      IndexedBagConsistency projection (empty TBag).
  Proof.
      unfold IndexedBagConsistency; 
      intros; rewrite empty_mapsto_iff in *; exfalso; trivial.
  Qed.

  Lemma consistency_key_eq :
    forall {TBag TItem TBagSearchTerm},
    forall bags_bag (projection: TItem -> TKey),
    forall (indexed_bag: @IndexedBag TBag TItem TBagSearchTerm bags_bag projection),
    forall (key: TKey) bag item,
      MapsTo key bag (ifmap indexed_bag) ->
      List.In item (benumerate bag) ->
      E.eq (projection item) key.
  Proof.
    intros.
    destruct indexed_bag as [? consistent].
    unfold IndexedBagConsistency in consistent.
    eapply consistent; eauto.
  Qed.

  Ltac destruct_if :=
    match goal with
        [ |- context [ if ?cond then _ else _ ] ] => destruct cond
    end.

  Lemma KeyFilter_true :
    forall {A} k projection (item: A),
      KeyFilter k projection item = true <-> E.eq (projection item) k.
  Proof.
    unfold KeyFilter; intros;
    destruct_if; intros; intuition.
  Qed.

  Lemma KeyFilter_false :
    forall {A} k projection (item: A),
      KeyFilter k projection item = false <-> ~ E.eq (projection item) k.
  Proof.
    unfold KeyFilter; intros;
    destruct_if; intros; intuition.
  Qed.

  Definition IndexedBag_bempty 
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm}
             (projection: TItem -> TKey) :=
    {| ifmap        := empty TBag;
       iconsistency := iconsistency_empty projection |}.

  Definition IndexedBag_bstar
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm} :=
    (@None TKey, @bstar _ _ _ bags_bag).


  Definition IndexedBag_bfind_matcher 
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm}
             (projection: TItem -> TKey)
             (key_searchterm: (option TKey) * TBagSearchTerm) (item: TItem) :=
    let (key_option, search_term) := key_searchterm in
    match key_option with
      | Some k => KeyFilter k projection item
      | None   => true 
    end && (bfind_matcher search_term item).

  Definition IndexedBag_benumerate 
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm}
             {projection: TItem -> TKey} 
             (container: @IndexedBag TBag TItem TBagSearchTerm bags_bag projection) :=
    flatten (List.map benumerate (Values (ifmap container))).

  Definition IndexedBag_bfind
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm}
             (projection: TItem -> TKey)
             (container: @IndexedBag TBag TItem TBagSearchTerm bags_bag projection) 
             (key_searchterm: (option TKey) * TBagSearchTerm) :=
    let (key_option, search_term) := key_searchterm in
    match key_option with
      | Some k =>
        match find k (ifmap container) with
          | Some bag => @bfind _ _ _ bags_bag bag search_term
          | None     => []
        end
      | None   =>
        flatten (List.map (fun bag =>  @bfind _ _ _ bags_bag bag search_term) (Values (ifmap container)))
    end.

  Lemma indexed_bag_insert_consistent :
    forall {TBag TItem TBagSearchTerm: Type}
           {bags_bag: Bag TBag TItem TBagSearchTerm}
           {projection: TItem -> TKey} 
           (container: @IndexedBag TBag TItem TBagSearchTerm bags_bag projection) 
           (item: TItem),
      let k := projection item in
      let fmap := ifmap container in
      let bag := FindWithDefault k bempty fmap in
      IndexedBagConsistency projection (add k (binsert bag item) fmap).
  Proof.
    intros.

    intros k' bag' maps_to item'.

    rewrite add_mapsto_iff in maps_to;
      destruct maps_to as [(is_eq & refreshed) | (neq & maps_to)];
      subst.

    rewrite (binsert_enumerate item' item bag).
    intro H; destruct H.
    apply (iconsistency container k' bag); trivial.    

    rewrite <- is_eq.
    unfold bag in *.

    unfold fmap in *.
    destruct (FindWithDefault_dec k (@bempty _ _ _ bags_bag) (ifmap container))
      as [ [bag' (mapsto & equality)] | (not_found & equality) ];
      rewrite equality in *; clear equality.

    subst; trivial.
    exfalso; apply (@benumerate_empty _ _ _ bags_bag) in H; trivial.
    
    subst.
    unfold k in *. 
    trivial.

    apply (iconsistency container k' bag' maps_to item').
  Qed.    

  Definition IndexedBag_binsert 
             {TBag TItem TBagSearchTerm: Type}
             {bags_bag: Bag TBag TItem TBagSearchTerm}
             (projection: TItem -> TKey)
             (container: @IndexedBag TBag TItem TBagSearchTerm bags_bag projection) 
             (item: TItem) : @IndexedBag TBag TItem TBagSearchTerm bags_bag projection :=
    let k := projection item in
    let fmap := ifmap container in
    let bag := FindWithDefault k bempty fmap in
    {|
      ifmap := add k (binsert bag item) fmap;
      iconsistency := indexed_bag_insert_consistent container item
    |}.

  Lemma IndexedBag_BagInsertEnumerate :
    forall {TBag TItem TBagSearchTerm: Type}
           {bags_bag: Bag TBag TItem TBagSearchTerm}
           (projection: TItem -> TKey),
      BagInsertEnumerate IndexedBag_benumerate (IndexedBag_binsert projection).
  Proof.

    unfold BagInsertEnumerate, Values, IndexedBag_benumerate.
    intros; simpl in *.

    setoid_rewrite in_flatten_iff.
    setoid_rewrite in_map_iff.
    setoid_rewrite <- MapsTo_snd.

    split; intro H.
    
    destruct H as [ items ( in_seq & [ bag (bag_items & [ key maps_to ]) ] ) ].
    pose proof maps_to as maps_to'.
    rewrite add_mapsto_iff in maps_to;
      destruct maps_to as [(is_eq & refreshed) | (neq & maps_to)].

    subst.
    rewrite (binsert_enumerate _) in in_seq.
    destruct in_seq as [ in_seq | ? ]; eauto.
    left.
    
    Ltac autoexists :=
      repeat progress match goal with
                        | [ |- exists _, _ ] => eexists; autoexists
                        | [ |- ?a = ?b ]     => first [ (has_evar a; has_evar b; idtac) | eauto]
                        | [ |- E.eq _ _ ]    => eauto
                        | [ |- _ /\ _ ]      => split; autoexists
                        | [ |- _ \/ _ ]      => left; autoexists
                      end.
    
    destruct (FindWithDefault_dec (projection inserted) bempty (ifmap container)) 
      as [ [result (mapsto & equality)] | (not_found & equality) ];
      rewrite equality in *; clear equality.
    
    autoexists; eauto.
    
    exfalso; apply benumerate_empty in in_seq; tauto.

    autoexists; eauto.

    destruct H as [ [ items ( in_seq & [ bag ( bag_items & [ key maps_to ] ) ] ) ] | eq_item_inserted ].
    
    pose proof maps_to as maps_to'.
    apply (iconsistency container) in maps_to.    
    setoid_rewrite bag_items in maps_to.
    specialize (maps_to item in_seq).
    
    setoid_rewrite add_mapsto_iff.

    destruct (E.eq_dec (projection inserted) key);
      try solve [ repeat (eexists; split; eauto) ].
    
    autoexists.

    apply binsert_enumerate.

    destruct (FindWithDefault_dec (projection inserted) bempty (ifmap container))
      as [ [bag' (mapsto & equality)] | (not_found & equality) ];
      rewrite equality in *; clear equality.

    rewrite e in mapsto.
    pose proof (MapsTo_fun mapsto maps_to') as bag'_bag.
    rewrite bag'_bag.
    rewrite bag_items.
    auto.

    rewrite find_mapsto_iff in maps_to'.
    rewrite <- e in maps_to'.
    match goal with 
      | [ H: ?a = Some ?b, H': ?a = None |- _ ] => assert (Some b = None) by (transitivity a; auto); discriminate
    end.

    subst item.
    match goal with
      | [ |- context [ add ?key ?value ?container ] ] => set (k := key); set (v := value)
    end.

    exists (benumerate v).

    split.

    unfold v.
    rewrite (binsert_enumerate _); auto.

    exists v; split; trivial.
    exists k.
    apply add_1; trivial.
  Qed.

  Lemma IndexedBag_BagEnumerateEmpty :
    forall {TBag TItem TBagSearchTerm: Type}
           {bags_bag: Bag TBag TItem TBagSearchTerm}
           (projection: TItem -> TKey),
      BagEnumerateEmpty IndexedBag_benumerate (IndexedBag_bempty projection).
  Proof.
    intros;
    unfold BagEnumerateEmpty, IndexedBag_benumerate, flatten; simpl;
    rewrite Values_empty; tauto.
  Qed.

  Lemma IndexedBag_BagFindStar :
    forall {TBag TItem TBagSearchTerm: Type}
           {bags_bag: Bag TBag TItem TBagSearchTerm}
           (projection: TItem -> TKey),
      BagFindStar (IndexedBag_bfind projection) IndexedBag_benumerate IndexedBag_bstar.
  Proof.
    unfold BagFindStar, IndexedBag_benumerate; simpl.
    
    intros; induction (Values (ifmap container)); simpl; trivial.
    rewrite (@bfind_star _ _ _ bags_bag).
    f_equal; trivial.
  Qed.

  Lemma IndexedBag_BagFindCorrect :
    forall {TBag TItem TBagSearchTerm: Type}
           {bags_bag: Bag TBag TItem TBagSearchTerm}
           (projection: TItem -> TKey),
      BagFindCorrect (IndexedBag_bfind projection)
                     (IndexedBag_bfind_matcher projection) IndexedBag_benumerate.
  Proof.
    intros.
    destruct search_term as (option_key, search_term).
    destruct option_key as [ key | ].

    (* Key provided *)

    unfold IndexedBag_benumerate, IndexedBag_bfind_matcher.
    pose (iconsistency container).
    unfold IndexedBagConsistency in i.

    rewrite filter_and'.

    rewrite flatten_filter.
    
    Lemma consist :
      forall 
        {TBag TItem TSearchTerm bags_bag projection} 
        (container: @IndexedBag TBag TItem TSearchTerm bags_bag projection),
      forall k,
        eq
          (flatten
             (List.map (List.filter (KeyFilter k projection))
                       (List.map benumerate (Values (ifmap container)))))
          match find k (ifmap container) with
            | Some bag => benumerate bag
            | None => []
          end.
    Proof.          
      intros.

      pose (iconsistency container); unfold IndexedBagConsistency in i.
      unfold Values.
      destruct (find k (ifmap container)) as [ bag | ] eqn:eqfind.

      rewrite <- find_mapsto_iff in eqfind.
      (* assert (exists k', MapsTo k' bag (ifmap container)) as eqfind' by (exists k; trivial).*)

      pose proof eqfind as maps_to.

      rewrite elements_mapsto_iff in eqfind.
      apply InA_split in eqfind.

      destruct eqfind as [ l1 [ y [ l2 (y_k_bag & decomp) ] ] ].
      rewrite decomp.
      
      rewrite (map_map snd benumerate).
      rewrite ! map_app; simpl.
      
      pose proof (elements_3w (ifmap container)) as no_dup.
      rewrite decomp in no_dup; apply NoDupA_swap in no_dup; eauto using equiv_eq_key.

      inversion no_dup as [ | ? ? y_not_in no_dup' ]; subst.
      rewrite InA_app_iff in y_not_in by eauto using equiv_eq_key.
      
      unfold eq_key_elt in y_k_bag; simpl in y_k_bag.
      destruct y_k_bag as (y_k & y_bag).

      assert (forall k' bag', InA (@eq_key_elt _) (k', bag') (l1 ++ l2) -> 
                              forall item, 
                                List.In item (benumerate bag') ->
                                ~ E.eq (projection item) k).
      {
        intros k' bag' in_app item in_bag'_items eq_k.

        rewrite InA_app_iff in in_app; eauto using equiv_eq_key_elt.
        pose proof in_app as in_app'.

        apply (InA_front_tail_InA _ _ y) in in_app.
        rewrite <- decomp, <- elements_mapsto_iff in in_app.

        pose proof (i _ _ in_app _ in_bag'_items) as eq_k'. 
        symmetry in eq_k.
        pose proof (E.eq_trans eq_k eq_k').

        assert (eq_key y (k', bag')) as y_eq by (unfold eq_key; simpl; eauto).

        destruct in_app' as [ in_seq | in_seq ];
          (apply (InA_eqke_eqk (k2 := fst y) (snd y)) in in_seq; eauto);
          rewrite <- surjective_pairing in in_seq; intuition.
      }

      Lemma In_InA :
        forall (A : Type) (l : list A) (eqA : relation A) (x : A),
          Equivalence eqA -> List.In x l -> InA eqA x l.
      Proof.
        induction l; intros; simpl in *.
        exfalso; eauto using in_nil.
        destruct H0.
        apply InA_cons_hd; subst; reflexivity.
        apply InA_cons_tl, IHl; trivial.
      Qed.

      rewrite ! map_filter_all_false;
        [ | intros subseq in_map item in_subseq;
            rewrite in_map_iff in in_map;
            destruct in_map as [ (k', bag') (benum_eq & in_seq) ];
            rewrite KeyFilter_false;
            
            simpl in benum_eq;
            subst subseq;
            apply (H k' bag'); 
            eauto;
            
            apply In_InA; eauto using equiv_eq_key_elt;
            rewrite in_app_iff;
            eauto 
              .. ].

      rewrite 
        flatten_app, 
      flatten_head, 
      !flatten_nils, 
      app_nil_l, app_nil_r, 
      <- y_bag,
      filter_all_true; trivial.

      intros;
        rewrite KeyFilter_true;
        apply (iconsistency container _ bag); eauto.

      Lemma nil_in_false :
        forall {A} seq,
          seq = [] <-> ~ exists (x: A), List.In x seq.
      Proof.
        split; intro H.
        intros [ x in_seq ]; subst; eauto using in_nil.
        destruct seq as [ | a ]; trivial.
        exfalso; apply H; exists a; simpl; intuition.
      Qed.
      
      rewrite nil_in_false.
      intros [item item_in].

      rewrite in_flatten_iff in item_in.
      do 2 setoid_rewrite in_map_iff in item_in.

      destruct item_in as 
          [ subseq 
              (in_subseq 
                 & [ subseq_prefilter 
                       ( pre_post_filter 
                           & [ bag 
                                 (eq_bag_pre_filter 
                                    & bag_in) ] ) ] ) ].

      subst subseq.
      rewrite filter_In in in_subseq.
      destruct in_subseq as (in_subseq_prefilter & key_filter).

      rewrite KeyFilter_true in key_filter.
      rewrite <- MapsTo_snd in bag_in.
      destruct bag_in as [k' maps_to].

      subst.
      rewrite <- key_filter in eqfind.
      rewrite <- (iconsistency container k' bag maps_to _ in_subseq_prefilter) in maps_to.
      rewrite find_mapsto_iff in maps_to.

      congruence.
    Qed.

    simpl.
    rewrite consist.
    destruct (find key (ifmap container)) as [ bag | ].

    apply bfind_correct.
    eauto using SetEq_Reflexive.

    (* No key provided *)

    simpl. unfold IndexedBag_benumerate, IndexedBag_bfind_matcher.
    rewrite flatten_filter.

    induction (Values (ifmap container)); simpl.

    compute; tauto.

    rewrite IHl.

    Lemma SetEq_app :
      forall {A: Type} (s1 t1 s2 t2: list A),
        (SetEq s1 s2) /\ (SetEq t1 t2) -> SetEq (s1 ++ t1) (s2 ++ t2).
    Proof.
      unfold SetEq; 
      intros A s1 t1 s2 t2 (s1s2 & t1t2); 
      split;
      rewrite ! in_app_iff;
      intro inApp;
      [ rewrite s1s2, t1t2 in inApp
      | rewrite <- s1s2, <- t1t2 in inApp ];
      trivial.
    Qed.

    apply SetEq_app; split; eauto using SetEq_Reflexive.
    apply bfind_correct.
  Qed.
  
  Instance IndexedBagAsBag 
           (TBag TItem TBagSearchTerm: Type) 
           (bags_bag: Bag TBag TItem TBagSearchTerm) (projection: TItem -> TKey) 
  : Bag 
      (@IndexedBag TBag TItem TBagSearchTerm bags_bag projection) 
      TItem 
      ((option TKey) * TBagSearchTerm) :=
    {| 
      bempty        := IndexedBag_bempty projection;
      bstar         := IndexedBag_bstar;
      bfind_matcher := IndexedBag_bfind_matcher projection;

      benumerate := IndexedBag_benumerate;
      bfind      := IndexedBag_bfind projection;
      binsert    := IndexedBag_binsert projection;

      binsert_enumerate := IndexedBag_BagInsertEnumerate projection;
      benumerate_empty  := IndexedBag_BagEnumerateEmpty projection;
      bfind_star        := IndexedBag_BagFindStar projection;
      bfind_correct     := IndexedBag_BagFindCorrect projection
    |}. 
End IndexedTree.

Definition ListAsBag_bfind 
           {TItem TSearchTerm: Type}
           (matcher: TSearchTerm -> TItem -> bool) 
           (container: list TItem) (search_term: TSearchTerm) :=
  List.filter (matcher search_term) container.

Definition ListAsBag_binsert 
           {TItem: Type}
           (container: list TItem) 
           (item: TItem) :=
  cons item container.

Lemma List_BagInsertEnumerate :
  forall {TItem: Type},
  BagInsertEnumerate id (ListAsBag_binsert (TItem := TItem)).
Proof.
  firstorder.
Qed.

Lemma List_BagFindStar :
  forall {TItem TSearchTerm: Type}
         (star: TSearchTerm)
         (matcher: TSearchTerm -> TItem -> bool)
         (find_star: forall (i: TItem), matcher star i = true),
  BagFindStar (ListAsBag_bfind matcher) id star.
Proof.
  intros;
  induction container; simpl; 
  [ | rewrite find_star, IHcontainer]; trivial.
Qed.

Lemma List_BagEnumerateEmpty :
  forall {TItem: Type},
    BagEnumerateEmpty id (@nil TItem).
Proof.
  firstorder.
Qed.
  
Lemma List_BagFindCorrect :
  forall {TItem TSearchTerm: Type}
         (matcher: TSearchTerm -> TItem -> bool),
         BagFindCorrect (ListAsBag_bfind matcher) matcher id.
Proof.
  firstorder.
Qed.

Instance ListAsBag
         {TItem TSearchTerm: Type}
         (star: TSearchTerm)
         (matcher: TSearchTerm -> TItem -> bool)
         (find_star: forall (i: TItem), matcher star i = true)
: Bag (list TItem) TItem TSearchTerm :=
  {| 
    bempty := [];
    bstar  := star;
    
    benumerate := id;
    bfind      := ListAsBag_bfind matcher;
    binsert    := ListAsBag_binsert;
    
    binsert_enumerate := List_BagInsertEnumerate;
    benumerate_empty  := List_BagEnumerateEmpty;
    bfind_star        := List_BagFindStar star matcher find_star;
    bfind_correct     := List_BagFindCorrect matcher
  |}.

Definition IsCacheable
           {TItem TAcc}
           (initial_value: TAcc)
           (cache_updater: TItem -> TAcc -> TAcc) :=
  forall seq1 seq2,
    SetEq seq1 seq2 ->
    (List.fold_right cache_updater initial_value seq1 =
     List.fold_right cache_updater initial_value seq2).

Record CachingBag 
       {TBag TItem TSearchTerm: Type} 
       {bag_bag: Bag TBag TItem TSearchTerm} 
       {TCachedValue: Type}
       {initial_cached_value: TCachedValue}
       {cache_updater: TItem -> TCachedValue -> TCachedValue} 
       {cache_updater_cacheable: IsCacheable initial_cached_value cache_updater} :=
  { 
    cbag:          TBag;
    ccached_value: TCachedValue;
    
    cfresh_cache:  List.fold_right cache_updater initial_cached_value (benumerate cbag) = ccached_value
  }.

(* Note: The caching interface provides the initial_cached_value
         parameter to allow implementations to gracefully handle empty
         caches. Should an empty/non-empty distinction be needed,
         initial_cached_value can be set to None, and TCachedValue
         replaced by an option type. *)

Lemma binsert_enumerate_SetEq {TContainer TItem TSearchTerm} (bag: Bag TContainer TItem TSearchTerm):
  forall inserted container,
    SetEq 
      (benumerate (binsert container inserted))
      (inserted :: (benumerate container)).
Proof.
  unfold SetEq; intros; simpl.
  setoid_rewrite or_comm; setoid_rewrite eq_sym_iff. 
  apply binsert_enumerate. 
Qed.

Lemma benumerate_empty_eq_nil {TContainer TItem TSearchTerm} (bag: Bag TContainer TItem TSearchTerm):
  (benumerate bempty) = []. 
Proof.
  pose proof (benumerate_empty) as not_in;
  unfold BagEnumerateEmpty in not_in.
  destruct (benumerate bempty) as [ | item ? ]; 
    simpl in *;
    [ | exfalso; apply (not_in item) ];
    eauto.
Qed.

Instance CachingBagAsBag 
         {TBag TItem TSearchTerm: Type} 
         {bag_bag: Bag TBag TItem TSearchTerm} 
         {TCachedValue: Type}
         {initial_cached_value: TCachedValue} 
         {cache_updater: TItem -> TCachedValue -> TCachedValue} 
         {cache_updater_cacheable: IsCacheable initial_cached_value cache_updater}
         : Bag (@CachingBag TBag TItem TSearchTerm bag_bag 
                            TCachedValue initial_cached_value cache_updater
                            cache_updater_cacheable) 
               TItem 
               TSearchTerm :=
  {| 
    bempty                         := {| cbag          := @bempty _ _ _ bag_bag; 
                                         ccached_value := initial_cached_value |};
    bstar                          := @bstar _ _ _ bag_bag;
    bfind_matcher search_term item := bfind_matcher search_term item;

    benumerate container        := benumerate container.(cbag);
    bfind container search_term := bfind container.(cbag) search_term; 
    binsert container item      := {| cbag          := binsert container.(cbag) item;
                                      ccached_value := cache_updater item container.(ccached_value) |} 
  |}.
Proof.    
  unfold BagInsertEnumerate; simpl; intros. apply binsert_enumerate.
  unfold BagEnumerateEmpty;  simpl; intros; apply benumerate_empty.
  unfold BagFindStar;        simpl; intros; apply bfind_star.
  unfold BagFindCorrect;     simpl; intros; apply bfind_correct.

  Grab Existential Variables.

  rewrite (cache_updater_cacheable _ _ (binsert_enumerate_SetEq bag_bag _ _));
  simpl; setoid_rewrite cfresh_cache; reflexivity.

  rewrite benumerate_empty_eq_nil; reflexivity.
Defined.

Lemma in_nil_iff :
  forall {A} (item: A),
    List.In item [] <-> False.
Proof.
  intuition.
Qed.

Lemma in_not_nil :
  forall {A} x seq,
    @List.In A x seq -> seq <> nil.
Proof.
  intros A x seq in_seq eq_nil.
  apply (@in_nil _ x).
  subst seq; assumption.
Qed.

Lemma in_seq_false_nil_iff :
   forall {A} (seq: list A),
     (forall (item: A), (List.In item seq <-> False)) <-> 
     (seq = []).
Proof.
  intros.
  destruct seq; simpl in *; try tauto.
  split; intro H.
  exfalso; specialize (H a); rewrite <- H; eauto.
  discriminate.
Qed.

Lemma seteq_nil_nil :
  forall {A} seq,
    @SetEq A seq nil <-> seq = nil.
Proof.
  unfold SetEq.
  intros; destruct seq.

  tauto.
  split; [ | discriminate ].
  intro H; specialize (H a).
  exfalso; simpl in H; rewrite <- H; eauto.
Qed.

Lemma seteq_nil_nil' :
  forall {A} seq,
    @SetEq A nil seq <-> seq = nil.
Proof.
  setoid_rewrite SetEq_Symmetric_iff.
  intro; exact seteq_nil_nil.
Qed.

Section CacheableFunctions.
  Section Generalities.
    Lemma foldright_compose :
      forall {TInf TOutf TAcc} 
             (g : TOutf -> TAcc -> TAcc) (f : TInf -> TOutf) 
             (seq : list TInf) (init : TAcc),
        List.fold_right (compose g f) init seq =
        List.fold_right g init (List.map f seq).
    Proof.
      intros; 
      induction seq; 
      simpl; 
      [  | rewrite IHseq ];
      reflexivity.
    Qed.            

    Lemma projection_cacheable :
      forall {TItem TCacheUpdaterInput TCachedValue} 
             (projection: TItem -> TCacheUpdaterInput)
             (cache_updater: TCacheUpdaterInput -> TCachedValue -> TCachedValue)
             (initial_value: TCachedValue),
        IsCacheable initial_value cache_updater -> 
        IsCacheable initial_value (compose cache_updater projection).
      Proof.
        unfold IsCacheable.
        intros * is_cacheable * set_eq. 
        rewrite !foldright_compose; 
          apply is_cacheable;
          rewrite set_eq;
          reflexivity.
      Qed.

      Definition AddCachingLayer
                 {TBag TItem TSearchTerm: Type} 
                 (bag: Bag TBag TItem TSearchTerm)
                 {TCacheUpdaterInput TCachedValue: Type}
                 (cache_projection: TItem -> TCacheUpdaterInput) 
                 (initial_cached_value: TCachedValue)
                 (cache_updater: TCacheUpdaterInput -> TCachedValue -> TCachedValue) 
                 (cache_updater_cacheable: IsCacheable initial_cached_value cache_updater) :=
        {|
          BagType       :=  @CachingBag TBag TItem TSearchTerm 
                                        bag TCachedValue initial_cached_value 
                                        (compose cache_updater cache_projection) 
                                        (projection_cacheable cache_projection 
                                                              cache_updater 
                                                              initial_cached_value 
                                                              cache_updater_cacheable);
          SearchTermType := TSearchTerm;
          BagProof       := _
        |}.

      Definition CacheImplementationEnsures
                 {TCacheUpdaterInput TCachedValue}
                 cache_property
                 (cache_updater: TCacheUpdaterInput -> TCachedValue -> TCachedValue) 
                 (initial_value: TCachedValue) :=
        forall seq (value: TCacheUpdaterInput),
          cache_property seq value (List.fold_right cache_updater initial_value seq).

      Definition ProjectedCacheImplementationEnsures
                 {TItem TCacheUpdaterInput TCachedValue}
                 cache_property
                 (cache_updater: TCacheUpdaterInput -> TCachedValue -> TCachedValue) 
                 (projection: TItem -> TCacheUpdaterInput)
                 (initial_value: TCachedValue) :=
        forall seq (item: TItem),
          cache_property (List.map projection seq) (projection item) (List.fold_right (compose cache_updater projection) initial_value seq).

      (* Formally equivalent to ProjectedCacheImplementationEnsures cache_property id initial_value *)

      Lemma generalize_to_projection :
        forall {TItem TCacheUpdaterInput TCachedValue} 
               {cache_updater: TCacheUpdaterInput -> TCachedValue -> TCachedValue}
               (projection: TItem -> TCacheUpdaterInput)
               (initial_value: TCachedValue)
               (cache_property: list TCacheUpdaterInput ->
                                TCacheUpdaterInput -> TCachedValue -> Type),
          (CacheImplementationEnsures          
             cache_property cache_updater initial_value) ->
          (ProjectedCacheImplementationEnsures
             cache_property cache_updater projection initial_value).
      Proof.
        unfold CacheImplementationEnsures, ProjectedCacheImplementationEnsures;
        intros * non_projected_proof *;
        rewrite foldright_compose;
        apply non_projected_proof.
      Qed.
  End Generalities.

  Section MaxCacheable.
    Definition IsMax m seq :=
      (forall x, List.In x seq -> x <= m) /\ List.In m seq.

    Add Parametric Morphism (m: nat) :
      (IsMax m)
        with signature (@SetEq nat ==> iff)
          as IsMax_morphism.
    Proof.
      firstorder.
    Qed.

    Definition ListMax default seq :=
      List.fold_right max default seq.

    Lemma le_r_le_max : 
      forall x y z,
        x <= z -> x <= max y z.
    Proof.
      intros x y z;
      destruct (Max.max_spec y z) as [ (comp, eq) | (comp, eq) ]; 
      rewrite eq;
      omega.
    Qed.

    Lemma le_l_le_max : 
      forall x y z,
        x <= y -> x <= max y z.
    Proof.
      intros x y z. 
      rewrite Max.max_comm.
      apply le_r_le_max.
    Qed.

    Lemma ListMax_correct_nil :
      forall seq default,
        seq = nil -> ListMax default seq = default.
    Proof.
      unfold ListMax; intros; subst; intuition.
    Qed.
    
    Lemma ListMax_correct :
      forall seq default,
        IsMax (ListMax default seq) (default :: seq).
    Proof.
      unfold IsMax; 
      induction seq as [ | head tail IH ]; 
      intros; simpl.
      
      intuition.

      specialize (IH default);
        destruct IH as (sup & in_seq).

      split. 

      intros x [ eq | [ eq | in_tail ] ].
      
      apply le_r_le_max, sup; simpl; intuition.
      apply le_l_le_max; subst; intuition.
      apply le_r_le_max, sup; simpl; intuition.

      destruct in_seq as [ max_default | max_in_tail ].

      rewrite <- max_default, Max.max_comm;
        destruct (Max.max_spec default head); 
        intuition.

      match goal with
        | [ |- context[ max ?a ?b ] ] => destruct (Max.max_spec a b) as [ (comp & max_eq) | (comp & max_eq) ]
      end; rewrite max_eq; intuition.
    Qed.

    Lemma Max_unique :
      forall {x y} seq,
        IsMax x seq ->
        IsMax y seq -> 
        x = y.
    Proof.
      unfold IsMax;
      intros x y seq (x_sup & x_in) (y_sup & y_in);
      specialize (x_sup _ y_in);
      specialize (y_sup _ x_in);
      apply Le.le_antisym; assumption.
    Qed.

    (* TODO: rename SetEq_append to SetEq_cons *)

    (* TODO: find a cleaner way than destruct; discriminate *)
    (* TODO: Look at reflexive, discriminate, congruence, absurd in more details *)
    Lemma ListMax_cacheable :
      forall initial_value,
        IsCacheable initial_value max.
    Proof.
      unfold IsCacheable.

      intros init seq1 seq2 set_eq;
        apply (Max_unique (init :: seq1));
        [ | setoid_rewrite (SetEq_append _ _ init set_eq) ];
        apply ListMax_correct.
    Qed.

    Definition cached_max_gt_property seq value cached_max :=
      List.In value seq -> S cached_max > value.

    Lemma cached_max_gt :
      forall default,
        CacheImplementationEnsures cached_max_gt_property max default. 
    Proof.
      unfold CacheImplementationEnsures, cached_max_gt_property; 
      intros;
      destruct (ListMax_correct seq default) as (sup & _);
      apply Gt.le_gt_S, sup;
      simpl; auto.
    Qed.

    Lemma cached_max_gt_projected' {TItem} projection :
      forall default,
        ProjectedCacheImplementationEnsures (TItem := TItem) cached_max_gt_property max projection default.
    Proof.
      unfold ProjectedCacheImplementationEnsures.
      unfold cached_max_gt_property.

      intros;
      apply (generalize_to_projection projection default cached_max_gt_property (cached_max_gt default));
      trivial.
    Qed.

      Lemma in_map_unproject :
        forall {A B} projection seq,
        forall item,
          @List.In A item seq ->
          @List.In B (projection item) (List.map projection seq).
      Proof.
        intros ? ? ? seq;
        induction seq; simpl; intros item in_seq.

        trivial.
        destruct in_seq;
          [ left; f_equal | right ]; intuition.
      Qed.

    Lemma cached_max_gt_projected : 
      forall {A} projection,
      forall default seq (item: A),
        List.In item seq -> S (List.fold_right (compose max projection) default seq) > (projection item).
    Proof.
      intros;
      apply (cached_max_gt_projected' projection);
      apply (in_map_unproject); trivial.
    Qed.
  End MaxCacheable.
End CacheableFunctions.

Require Import Tuple Heading.

Definition TSearchTermMatcher (heading: Heading) := (@Tuple heading -> bool).

Definition SearchTermsCollection heading :=
  list (TSearchTermMatcher heading).

Fixpoint MatchAgainstSearchTerms 
         {heading: Heading}
         (search_terms : SearchTermsCollection heading) (item: Tuple) :=
  match search_terms with
    | []                     => true
    | is_match :: more_terms => (is_match item) && MatchAgainstSearchTerms more_terms item
  end.

Definition HasDecidableEquality (T: Type) :=
  forall (x y: T), {x = y} + {x <> y}.

Definition TupleEqualityMatcher 
           {heading: Heading} 
           (attr: Attributes heading)
           (value: Domain heading attr) 
           {eq_dec: HasDecidableEquality (Domain heading attr)} : TSearchTermMatcher heading :=
  fun tuple => 
    match eq_dec (tuple attr) value with
      | in_left  => true
      | in_right => false
    end.

Instance TupleListAsBag (heading: Heading) :
  Bag (list (@Tuple heading)) (@Tuple heading) (SearchTermsCollection heading).
Proof.
  apply (ListAsBag [] (@MatchAgainstSearchTerms heading)); eauto.
Defined.

Require Import Beatles.
Require Import StringBound.
Require Import Peano_dec.
Require Import String_as_OT.

Open Scope string_scope.
Open Scope Tuple_scope.

(*
Eval simpl in (bfind FirstAlbums [ TupleEqualityMatcher (eq_dec := string_dec) Name "Please Please Me" ]).
Eval simpl in (bfind FirstAlbums [ TupleEqualityMatcher (eq_dec := eq_nat_dec) Year 3]).
Eval simpl in (bfind FirstAlbums [ TupleEqualityMatcher (eq_dec := eq_nat_dec) Year 3; TupleEqualityMatcher (eq_dec := eq_nat_dec) UKpeak 1]).
*)

Module NatIndexedMap := FMapAVL.Make Nat_as_OT.
Module StringIndexedMap := FMapAVL.Make String_as_OT.

Module NatTreeExts := IndexedTree NatIndexedMap.
Module StringTreeExts := IndexedTree StringIndexedMap.

Definition NatTreeType TSubtree TSubtreeSearchTerm heading subtree_as_bag := 
  (@NatTreeExts.IndexedBag 
     TSubtree 
     (@Tuple heading) 
     TSubtreeSearchTerm 
     subtree_as_bag).

Definition StringTreeType TSubtree TSubtreeSearchTerm heading subtree_as_bag := 
  (@StringTreeExts.IndexedBag 
     TSubtree 
     (@Tuple heading) 
     TSubtreeSearchTerm
     subtree_as_bag).

Definition cast {T1 T2: Type} (eq: T1 = T2) (x: T1) : T2.
Proof.
  subst; auto.
Defined.

Record ProperAttribute {heading} :=
  {
    Attribute: Attributes heading; 
    ProperlyTyped: { Domain heading Attribute = nat } + { Domain heading Attribute = string }
  }.

Fixpoint NestedTreeFromAttributes'
         heading 
         (indexes: list (@ProperAttribute heading)) 
         {struct indexes}: (@BagPlusBagProof (@Tuple heading)) :=
  match indexes with
    | [] => 
      {| BagType        := list (@Tuple heading);
         SearchTermType := SearchTermsCollection heading |}
    | proper_attr :: more_indexes => 
      let attr := @Attribute heading proper_attr in
      let (t, st, bagproof) := NestedTreeFromAttributes' heading more_indexes in
      match (@ProperlyTyped heading proper_attr) with
        | left  eq_nat    => 
          {| BagType        := NatTreeType    t st heading bagproof (fun x => cast eq_nat    (x attr));
             SearchTermType := option nat    * st |}
        | right eq_string => 
          {| BagType        := StringTreeType t st heading bagproof (fun x => cast eq_string (x attr));
             SearchTermType := option string * st |}
      end
    end.

Lemma eq_attributes : forall seq (a b: @BoundedString seq),
             a = b <-> (bindex a = bindex b /\ (ibound (indexb a)) = (ibound (indexb b))).
  split; intros; 
  simpl in *;
  try (subst; tauto);
  apply idx_ibound_eq; 
    intuition (apply string_dec).
Qed.

Definition CheckType {heading} (attr: Attributes heading) (rightT: _) :=
  {| Attribute := attr; ProperlyTyped := rightT |}.

Ltac autoconvert func :=
  match goal with 
    | [ src := cons ?head ?tail |- list _ ] =>
      refine (func head _ :: _);
        [ solve [ eauto with * ] | clear src;
                            set (src := tail);
                            autoconvert func ]
    | [ src := nil |- list _ ] => apply []
    | _ => idtac
  end.

Ltac mkIndex heading attributes :=
  set (src := attributes);
  assert (list (@ProperAttribute heading)) as decorated_source by autoconvert (@CheckType heading);
  apply (NestedTreeFromAttributes' heading decorated_source).

Definition SampleIndex : @BagPlusBagProof (@Tuple AlbumHeading).
Proof.
  mkIndex AlbumHeading [Year; UKpeak; Name].
Defined.

Definition IndexedAlbums :=
  List.fold_left binsert FirstAlbums (@bempty _ _ _ (BagProof SampleIndex)).

(*
Eval simpl in (SearchTermType SampleIndex).
Time Eval simpl in (bfind IndexedAlbums (Some 3, (None, (None, [])))).
Time Eval simpl in (bfind IndexedAlbums (Some 3, (Some 1, (None, [])))).
Time Eval simpl in (bfind IndexedAlbums (Some 3, (Some 1, (Some "With the Beatles", [])))).
Time Eval simpl in (bfind IndexedAlbums (None, (None, (Some "With the Beatles", [])))).
Time Eval simpl in (bfind IndexedAlbums (None, (None, (None, [TupleEqualityMatcher (eq_dec := string_dec) Name "With the Beatles"])))).

(*Time Eval simpl in (@bfind _ _ _ (BagProof _ SampleIndex) IndexedAlbums (Some 3, (Some 1, (None, @nil (TSearchTermMatcher AlbumHeading))))).*)
*)
